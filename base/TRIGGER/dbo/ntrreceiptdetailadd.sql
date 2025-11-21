SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure:  ntrReceiptDetailAdd                                      */
/* Creation Date:                                                             */
/* Copyright: Maersk                                                          */
/* Written by:                                                                */
/*                                                                            */
/* Purpose:  ReceiptDetailAdd Trigger                                         */
/*                                                                            */
/* Input Parameters:                                                          */
/*                                                                            */
/* Output Parameters:  None                                                   */
/*                                                                            */
/* Return Status:  None                                                       */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/* Local Variables:                                                           */
/*                                                                            */
/* Called By:                                                                 */
/*                                                                            */
/* PVCS Version: 1.16                                                         */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.   Purposes                                     */
/* 26-Aug-2002  Vicky            Setup DefaultLottable_Returns to Facility    */
/*                               level (SOS33412)                             */
/* 11-Sep-2002  RickyYee         Merge code from SOS, FBR and Performance     */
/*                               tuning from July 13th till Aug 23th          */
/* 13-Nov-2002  RickyYee         To fixed the Allow_overreceipt               */
/* 21-Nov-2002  Vicky            Patched modification by Wally from IDSPH -   */
/*                               Consider Freegoodqty (SOS8648)               */
/* 21-Apr-2003  June             Obtain facility value for nspg_getright      */
/*                               for configure flag 'allow_overreceipt'       */
/* 04-Jun-2003  Vicky            (Merger from Branch 1.4.1.1) - To include    */
/*                               IDSPH CDC changes                            */
/* 18-Feb-2004  Shong            Thailand Performance Tuning                  */
/* 19-Apr-2004  Shong            WeekNumber in lottable01 field is not        */
/*                               being updated until receipt is finalized     */
/*                               (SOS22173)                                   */
/* 26-Apr-2004  Shong            Bug Fixed                                    */
/* 01-Apr-2005  MaryVong         Setup DefaultLottable_Returns to Facility    */
/*                               level (SOS33412)                             */
/* 18-Apr-2005  MaryVong         Create Receipt Date for Lottable05 after     */
/*                               Finalized (SOS28761)                         */
/* 05-May-2005  YokeBeen         UCC Receiving and Putaway - NSC Project.     */
/*                               - (FBR/SOS#34647) - (YokeBeen01)             */
/* 02-Jun-2005  UngDH            To support RDT                               */
/* 18-Dec-2007  Shong            Remove Decimal Point for SUSR4 and SUSR1     */
/*                               if user included .00 at the back (SHONG001)  */
/*                                                                            */
/* 08-Feb-2008  Shong            Add new Config NoSamePO2DiffASN SOS85460     */
/* 24-Sep-2008  KC        1.1    SOS# 115735 Pass facility to nspGetRight     */
/*                               for configkey 'ByPassTolerance'              */
/* 23-Dec-2009  James            Skip trigger firing if archivecop = '9'      */
/* 06-Oct-2011  tlting01  1.4    Not allow change qtyreceived & qtyexpected   */
/*                               after ASNStatus ='9' SOS226641               */
/* 02-Jun-2013  MCTang    1.5    SOS#280456 Add 'LOTCHGLOG' (MC01)            */
/* 17-Oct-2013  Shong     1.6    Dead Lock Patches                            */
/* 28-May-2014  TLTING02  1.7    Bug fix                                      */
/* 24-Jul-2014  CSCHONG   1.8    Add Lottable06-15 (CS01)                     */
/* 02-May-2014  NJOW01    1.8    309551-Cofigure codelkup to exclude lottable */
/*                               label checking by document type.             */
/* 26-Jan-2015  TKLIM     1.9    Fixed Typo for Error 601112 and 601115 (TK01)*/
/* 31-Mar-2015  CSCHONG   2.0    SOS#337342 avoid invalid sku to be add (CS01)*/
/* 26-Apr-2015  Leong     2.1    Bug fix (Leong01).                           */
/* 08-Sep-2015  James     2.2    Revamp error no (james01)                    */
/* 22-Jan-2015  TKLIM     2.3    New StorerConfig PopulatePalletLabel (TK02)  */
/* 02-Aug-2016  Ung       2.4    IN00110559 Enable trigger pass out error     */
/* 24-Jan-2017  TLTING    2.5    Remove SET Rowcount                          */
/* 03-May-2017  NJOW02    2.6    WMS-1798 Allow config to call custom sp      */
/* 06-Jul-2017  NJOW03    2.7    WMS-2291 Retrun include receipt type 'RGR' for*/
/*                               extract oldest lot5 by matching lot1-4       */
/* 30-Jul-2017  Barnett   2.8    FBR-2352 Logic change on Insert PrintLabel   */
/*                               record (BL01)                                */
/* 08-Aug-2018  JihHaur   2.9    INC0366341 Comment out(BL01) change to delete*/
/*                               existing record (JH01)                       */
/* 07-Feb-2018  SWT02     3.0    Channel Management                           */
/* -------------------------------------------------------------------------- */
/* 13-Jun-2019  YokeBeen  1.16  WMS-8202 - Base on PVCS EXCEED_TG_V7          */
/*                              version 1.15. Auto set ASNStatus = '1' upon   */
/*                              Receiving Starts - (YokeBeen02)               */
/* 15-Apr-2020  NJOW04    3.1   WMS-12880 add offset to ReturnDefaultLottable05*/ 
/* 01-Jun-2021  NJOW05    3.2   WMS-16944 additional from ASNStatus change    */
/*                              to status 1 by codelkup                       */
/* 01-Jun-2021  NJOW05    3.2   DEVOPS combine script                         */
/* 04-Aug-2022  WLChooi   3.3   WMS-20405 - Add ReceiptType 'VFEGRN' (WL01)   */
/* 15-Mar-2024  Wan01     3.4   UWP-16968-Post PalletType to Inventory When   */
/*                              Finalize                                      */
/* 01-Oct-2024  SSA01     3.5   UWP-24927-Ignore blank or Null POKEY          */
/******************************************************************************/

CREATE   TRIGGER [dbo].[ntrReceiptDetailAdd]
ON  [dbo].[RECEIPTDETAIL]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   ,       @c_authority NVARCHAR(1) -- Added for IDSV5 by June 25.Jun.02
   ,       @c_StorerKey NVARCHAR(15)
   ,       @c_Sku       NVARCHAR(20)
   SELECT @b_debug = 0

   DECLARE  @c_CatchWeightFlag         NVARCHAR(1),
          @c_authority_OverRcp         NVARCHAR(1),
          @c_authority_ucc             NVARCHAR(1),
          @c_PopulateSubInv            NVARCHAR(1)
   ,      @c_DefaultLottable_Returns   NVARCHAR(1) -- Added by June 25.Jun.02 for IDSV5
   ,      @c_ByPassTolerance           NVARCHAR(1)
   ,      @c_Authority_RtnValid        NVARCHAR(1)
   ,      @c_DisallowInValidSKU        NVARCHAR(1)         --(CS01)
   ,      @c_SkuStatus                 NVARCHAR(10)        --(CS01)
   ,      @c_skustatusFlag             NVARCHAR(60)        --(CS01) 

   IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT @profiler = 'PROFILER,637,00,0,ntrReceiptDetailAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114)
      PRINT @profiler
   END

   DECLARE
          @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
   ,      @n_err                int       -- Error number returned by stored procedure or this trigger
   ,      @n_err2 int              -- For Additional Error Detection
   ,      @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,      @n_continue int
   ,      @n_starttcnt int                -- Holds the current transaction count
   ,      @c_preprocess NVARCHAR(250)         -- preprocess
   ,      @c_pstprocess NVARCHAR(250)         -- post process
   ,      @n_cnt int
   ,      @c_Facility NVARCHAR(5)

   DECLARE @c_PODLottable01      NVARCHAR(18)
         , @c_PODLottable02      NVARCHAR(18)
         , @c_PODLottable03      NVARCHAR(18)
         , @d_PODLottable04      DATETIME
         , @d_PODLottable05      DATETIME
         , @c_TransmitlogKey     NVARCHAR(10)
         , @c_LOTCHGLOG          CHAR(1)
         , @c_ReceiptLineNumber  NVARCHAR(5)
         , @c_POLineNumber       NVARCHAR(5)
         , @c_PODLottable06      NVARCHAR(30)     --CS01
         , @c_PODLottable07      NVARCHAR(30)     --CS01
         , @c_PODLottable08      NVARCHAR(30)     --CS01
         , @c_PODLottable09      NVARCHAR(30)     --CS01
         , @c_PODLottable10      NVARCHAR(30)     --CS01
         , @c_PODLottable11      NVARCHAR(30)     --CS01
         , @c_PODLottable12      NVARCHAR(30)     --CS01
         , @d_PODLottable13      DATETIME         --CS01
         , @d_PODLottable14      DATETIME         --CS01
         , @d_PODLottable15      DATETIME         --CS01
         , @c_PopPalletLabel     NVARCHAR(10)     --TK02
         , @c_DeftLot_Returns_Opt1 NVARCHAR(50)   --NJOW04
         , @c_PalletType         NVARCHAR(10) = ''                                  --(Wan01)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   /* #INCLUDE <TRRDA1.SQL> */

   -- To Skip all the trigger process when Insert the history records from Archive as user request
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
      SELECT @n_continue = 4

   ---------------------------------
   -- Added By SHONG on 08th Feb 2008
   -- SOS85460 - Not Allow to Populate Same PO to more then 1 Receipt.
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE @c_ChkPOKey            NVARCHAR(10),
              @c_ConfigFlag_On       NVARCHAR(1),
              @c_InsertedReceiptKey  NVARCHAR(10)

      DECLARE C_CheckDuplicatePOKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT StorerKey
                    , POKey
                    , ReceiptKey
      FROM INSERTED
      WHERE POKey <> '' AND POKey IS NOT NULL                  --(SSA01)

      OPEN C_CheckDuplicatePOKey

      FETCH NEXT FROM C_CheckDuplicatePOKey INTO @c_StorerKey, @c_ChkPOKey, @c_InsertedReceiptKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @b_success = 0
         Execute nspGetRight @c_Facility,   -- facility
                   @c_StorerKey,    -- Storerkey
                   null,            -- Sku
                   'NoSamePO2DiffASN', -- Configkey
                   @b_success         output,
                   @c_ConfigFlag_On   output,
                   @n_err             output,
                   @c_errmsg          output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60129
            BREAK
         END
         ELSE IF @c_ConfigFlag_On = '1'
         BEGIN
            IF EXISTS(SELECT 1 FROM RECEIPTDETAIL (NOLOCK) WHERE POKey = @c_ChkPOKey
                      AND ReceiptKey <> @c_InsertedReceiptKey)
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'Not Allow to Populate Same PO to more then 1 Receipt. (ntrReceiptDetailAdd)'
               SELECT @n_err = 60130
               BREAK
            END
         END

         FETCH NEXT FROM C_CheckDuplicatePOKey INTO @c_StorerKey, @c_ChkPOKey, @c_InsertedReceiptKey
      END -- WHile
      CLOSE C_CheckDuplicatePOKey
      DEALLOCATE C_CheckDuplicatePOKey
   END

   IF @n_continue = 3
   BEGIN
      GOTO QUIT
   END

   -- tlting01 6-Oct 2011
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS(SELECT 1  FROM RECEIPT WITH (NOLOCK)
                JOIN INSERTED ON (INSERTED.RECEIPTKey = RECEIPT.RECEIPTKey)
                WHERE RECEIPT.ASNStatus = '9'
                )
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err = 60131
         SELECT @c_errmsg  ='NSQL' + CONVERT(char(5),@n_err) + 'Receipt Closed! Update on table ReceiptDetail Rejected. (ntrReceiptDetailAdd)'
         GOTO QUIT
      END
   END

   --NJOW02
   IF @n_continue=1 or @n_continue=2          
   BEGIN      
      IF EXISTS (SELECT 1 FROM INSERTED d   ----->Put INSERTED if INSERT action
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
                   'INSERT'  -----> @c_Action can be INSERT, UPDATE, DELETE
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrReceiptDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END      

   /*--------->>>>> End FBRC03-1 <<<<<----------*/
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,01,0,PODDETAIL Update                                  ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END

      -- Modify By SHONG on 12th Jun 2003
      -- Performance Tuning
      --IF EXISTS(SELECT 1 FROM INSERTED (NOLOCK) WHERE dbo.fnc_RTrim(POKEY) IS NOT NULL AND dbo.fnc_RTrim(POKEY) <> '')
      -- 17-Oct-2013  Shong
      IF EXISTS(SELECT 1 FROM INSERTED (NOLOCK) WHERE POKEY IS NOT NULL AND POKEY <> '' AND INSERTED.QtyReceived > 0)
      BEGIN
         UPDATE PODETAIL WITH (ROWLOCK)
         SET PODETAIL.QtyReceived = PODETAIL.QtyReceived + INSERTED.QtyReceived
         FROM PODETAIL, INSERTED
         WHERE  PODETAIL.POKey = INSERTED.POKey
         AND PODETAIL.POLineNumber = INSERTED.POLineNumber
         -- END of Modification (SHONG)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update Failed On Table PODETAIL. (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,01,9,PODETAIL Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END

   IF @n_continue = 1 OR @n_continue=2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,02,0,ITRN Deposit Process                              ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END

      DECLARE @ReceiptPrimaryKey NVARCHAR(15),
      @n_ItrnSysId   int,
      @c_Lot         NVARCHAR(10),
      @c_ToLoc       NVARCHAR(10),
      @c_ToID        NVARCHAR(18),
      @c_Status      NVARCHAR(10),
      @c_Lottable01  NVARCHAR(18),
      @c_Lottable02  NVARCHAR(18),
      @c_Lottable03  NVARCHAR(18),
      @d_Lottable04  datetime,
      @d_Lottable05  datetime,
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
      @c_POKey        NVARCHAR(18) ,
      @c_finalizeflag NVARCHAR(1),
      @c_Lottable06  NVARCHAR(30),    --(CS01)
      @c_Lottable07  NVARCHAR(30),    --(CS01)
      @c_Lottable08  NVARCHAR(30),    --(CS01)
      @c_Lottable09  NVARCHAR(30),    --(CS01)
      @c_Lottable10  NVARCHAR(30),    --(CS01)
      @c_Lottable11  NVARCHAR(30),    --(CS01)
      @c_Lottable12  NVARCHAR(30),    --(CS01)
      @d_Lottable13  datetime,        --(CS01)
      @d_Lottable14  datetime,        --(CS01)
      @d_Lottable15  DATETIME,        --(CS01)
      @c_Channel     NVARCHAR(20),  -- (SWT02)
      @n_Channel_ID  BIGINT         -- (SWT02)
   
      -- Added By Shong 1st Aug
      DECLARE @c_ReceiptType NVARCHAR(10)

      DECLARE @c_Lottable01Label NVARCHAR(20),
           @c_Lottable02Label NVARCHAR(20),
           @c_Lottable03Label NVARCHAR(20),
           @c_Lottable04Label NVARCHAR(20),
           @c_Lottable05Label NVARCHAR(20),
           @c_RecType         NVARCHAR(10),
           @c_ExternLineNo    NVARCHAR(20),
           @n_TotQtyReceived  int,
           @c_CopyPackKey     NVARCHAR(1),
           @n_QtyExpected     int,
           @c_authority_02    NVARCHAR(1),
           @n_IncomingShelfLife BIGINT,  --tlting02
           @c_SubReasonCode   NVARCHAR(10),
           @n_TolerancePerc   BIGINT,  --tlting02
           @c_authority_ExpReason NVARCHAR(1),
           @c_DocType             NVARCHAR(1), --NJOW01
           @c_Lottable06Label NVARCHAR(20),      --(CS01)
           @c_Lottable07Label NVARCHAR(20),       --(CS01)
           @c_Lottable08Label NVARCHAR(20),       --(CS01)
           @c_Lottable09Label NVARCHAR(20),       --(CS01)
           @c_Lottable10Label NVARCHAR(20),       --(CS01)
           @c_Lottable11Label NVARCHAR(20),       --(CS01)
           @c_Lottable12Label NVARCHAR(20),       --(CS01)
           @c_Lottable13Label NVARCHAR(20),       --(CS01)
           @c_Lottable14Label NVARCHAR(20),       --(CS01)
           @c_Lottable15Label NVARCHAR(20)       --(CS01)


      SELECT @ReceiptPrimaryKey = ' '
      WHILE (1 = 1) OR (@n_continue = 1 or @n_continue=2)
      BEGIN
         SET @n_Channel_ID= 0 
      
         SELECT TOP 1 @ReceiptPrimaryKey = INSERTED.ReceiptKey  + INSERTED.ReceiptLineNumber,
               @n_ItrnSysId   = NULL,
               @c_StorerKey   = INSERTED.StorerKey,
               @c_Sku         = INSERTED.SKU,
               @c_Lot         = '',
               @c_ToLoc       = INSERTED.ToLoc,
               @c_ToID        = INSERTED.ToID,
               @c_Status      = INSERTED.ConditionCode,
               @c_Lottable01  = INSERTED.Lottable01,
               @c_Lottable02  = INSERTED.Lottable02,
               @c_Lottable03  = INSERTED.Lottable03,
               @d_Lottable04  = INSERTED.Lottable04,
               @d_Lottable05  = INSERTED.Lottable05,
               @c_Lottable06  = INSERTED.Lottable06,
               @c_Lottable07  = INSERTED.Lottable07,
               @c_Lottable08  = INSERTED.Lottable08,
               @c_Lottable09  = INSERTED.Lottable09,
               @c_Lottable10  = INSERTED.Lottable10,
               @c_Lottable11  = INSERTED.Lottable11,
               @c_Lottable12  = INSERTED.Lottable12,
               @d_Lottable13  = INSERTED.Lottable13,
               @d_Lottable14  = INSERTED.Lottable14,
               @d_Lottable15  = INSERTED.Lottable15,
               @n_casecnt     = INSERTED.casecnt,
               @n_innerpack   = INSERTED.innerpack,
               @n_Qty         = INSERTED.QtyReceived,
               @n_TotQtyReceived = INSERTED.QtyReceived,
               @n_QtyExpected = INSERTED.QtyExpected,
               @n_pallet      = INSERTED.pallet,
               @f_cube        = INSERTED.cube,
               @f_grosswgt    = INSERTED.grosswgt,
               @f_netwgt      = INSERTED.netwgt,
               @f_otherunit1  = INSERTED.otherunit1,
               @f_otherunit2  = INSERTED.otherunit2,
               @c_packkey     = INSERTED.packkey,
               @c_uom         = INSERTED.uom ,
               @c_SourceKey   = INSERTED.ReceiptKey  + INSERTED.ReceiptLineNumber,
               @c_SourceType  = 'ntrReceiptDetailAdd',
               @d_EffectiveDate = INSERTED.EffectiveDate,
               @b_Success     = 0,
               @n_err         = 0,
               @c_errmsg      = ' ',
               @c_POKey        = INSERTED.pokey ,
               @c_POLineNumber = INSERTED.POLineNumber,           --(MC01)
               @c_ReceiptLineNumber = INSERTED.ReceiptLineNumber, --(MC01)
               @c_finalizeflag = INSERTED.finalizeflag,
               @c_Lottable01Label = SKU.Lottable01Label,
               @c_Lottable02Label = SKU.Lottable02Label,
               @c_Lottable03Label = SKU.Lottable03Label,
               @c_Lottable04Label = SKU.Lottable04Label,
               @c_Lottable05Label = SKU.Lottable05Label,
               @c_Lottable06Label = SKU.Lottable06Label,
               @c_Lottable07Label = SKU.Lottable07Label,
               @c_Lottable08Label = SKU.Lottable08Label,
               @c_Lottable09Label = SKU.Lottable09Label,
               @c_Lottable10Label = SKU.Lottable10Label,
               @c_Lottable11Label = SKU.Lottable11Label,
               @c_Lottable12Label = SKU.Lottable12Label,
               @c_Lottable13Label = SKU.Lottable13Label,
               @c_Lottable14Label = SKU.Lottable14Label,
               @c_Lottable15Label = SKU.Lottable15Label,
               @c_RecType         = RECEIPT.RecType,
               @c_Facility        = RECEIPT.Facility,
               -- (SHONG001) Remove decimal point
               -- TLTING02 - BigINT Bug fix
               @n_IncomingShelfLife  = CASE WHEN SKU.SUSR1 IS NOT NULL AND IsNumeric(SKU.SUSR1) = 1
                                            THEN Convert(Bigint, CONVERT(Float, SKU.SUSR1))
                                            ELSE 0
                                       END,
               @c_SubReasonCode   = INSERTED.SubReasonCode,
               @c_ExternLineNo    = INSERTED.ExternLineNo,
               -- (SHONG001) Remove decimal point
               @n_TolerancePerc   = CASE WHEN SKU.SUSR4 IS NOT NULL AND IsNumeric(SKU.SUSR4) = 1
                                         THEN Convert(Bigint, CONVERT(Float, SKU.SUSR4))
                                         ELSE 0
                                    END,
               @c_CopyPackKey     = SKU.OnReceiptCopyPackkey,
               @c_DocType         = RECEIPT.DocType,  --NJOW01
               @c_Channel         = INSERTED.Channel  --(SWT02) 
            ,  @c_PalletType      = INSERTED.PalletType                             --(Wan01)
         FROM INSERTED
         JOIN SKU (NOLOCK) ON (INSERTED.SKU = SKU.SKU AND INSERTED.StorerKey = SKU.StorerKey)
         JOIN RECEIPT (NOLOCK) ON (RECEIPT.ReceiptKey = INSERTED.ReceiptKey )
         WHERE INSERTED.ReceiptKey  + INSERTED.ReceiptLineNumber > @ReceiptPrimaryKey
         -- AND (INSERTED.QtyReceived  > 0  OR INSERTED.BeforeReceivedQty > 0 )
         ORDER BY INSERTED.ReceiptKey ,INSERTED.ReceiptLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         -- (YokeBeen01) - Start
         IF @n_continue=1 OR @n_continue=2
         BEGIN
            DECLARE @c_NIKEBHHITF NVARCHAR(1),
                    @c_ReceiptKey NVARCHAR(10)
            SELECT @c_NIKEBHHITF = '0',
                   @c_ReceiptKey = SUBSTRING(@ReceiptPrimaryKey,1,10)
            SELECT @b_success = 0

            EXECUTE nspGetRight NULL,   -- Facility
                    @c_StorerKey,      -- Storer
                    NULL,               -- No Sku in this Case
                    'NIKEBHHITF',      -- ConfigKey
                    @b_success           output,
                    @c_NIKEBHHITF        output,
                    @n_err               output,
                    @c_errmsg            output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60132
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Retrieve Failed On GetRight. (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            ELSE IF @c_NIKEBHHITF = '1'
            BEGIN
               EXEC ispGenTransmitLog 'BATCHANDHELD', @c_ReceiptKey, '', @c_StorerKey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60133
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Unable to obtain TransmitLogkey (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- IF @b_success
         END
         -- (YokeBeen01) - End

         IF @c_CatchWeightFlag = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM LOTxIDDETAIl (NOLOCK), INSERTED
                        WHERE LOTxIDDetail.ReceiptKey  = SUBSTRING(@c_SourceKey,1,10)
                          AND LOTxIDDetail.ReceiptLineNumber = SUBSTRING(@c_SourceKey,11,5) )
            BEGIN
               SELECT @f_grosswgt = @f_grosswgt + @n_Qty * TareWeight
               FROM  SKU (NOLOCK)
               WHERE SKU.StorerKey = @c_storerkey
               AND SKU.SKU = @c_sku
               AND SKU.IOFlag in ('I', 'B')
            END
         END

         -- Default Lottable 01 Start
         IF @c_CopyPackKey = '1'
         BEGIN
            SELECT @c_Lottable01 = @c_PackKey
         END

         IF @c_Lottable01Label = 'GEN_WEEK' AND @d_Lottable04 IS NOT NULL
         BEGIN
            SELECT @c_Lottable01 = CONVERT(CHAR(4), DATEPART(YEAR, @d_Lottable04))
                  + (REPLICATE('0', 2-LEN(CONVERT(CHAR(2), DATEPART(wk, @d_Lottable04))))
                  + CONVERT(CHAR(2), DATEPART(wk, @d_Lottable04)))
         END
         -- Default Lottable 01 END

         -- Default Lottable02 Start
         -- This customization is for HK use. It looks at Lottable02Label = 'GDS_BATCH'
         -- 2001/10/01 CS IDSHK FBR061 populate Lottable02 as current date if it is not specified
         IF @c_Lottable02Label = 'GDS_BATCH'
         BEGIN
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02)) = '' or dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02)) IS  NULL
            BEGIN
               SELECT @c_Lottable02 = CONVERT(CHAR(8), GETDATE(), 112) -- YYYYMMDD
            END
         END
         -- 10.1.99 WALLY

         SELECT @b_success = 0
         EXECUTE nspGetRight null,  -- facility
               @c_StorerKey,  -- Storerkey
               @c_Sku,           -- Sku
               'Update Lot04 to Lot03', -- Configkey
               @b_success     output,
               @c_authority_02   output,
               @n_err         output,
               @c_errmsg      output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60134
         END
         ELSE IF @c_authority_02 = '1'
         BEGIN
            IF @c_Lottable02Label = 'GEN_WEEK' AND @d_Lottable04 IS NOT NULL
            BEGIN
               SELECT @c_Lottable02 = CONVERT(CHAR(4), DATEPART(YEAR, @d_Lottable04))
                     + (REPLICATE('0', 2-LEN(CONVERT(CHAR(2), DATEPART(wk, @d_Lottable04))))
                     + convert(CHAR(2), DATEPART(wk, @d_Lottable04)))
            END
         END
         -- Default Lottable02 END

         -- SOS28761
         -- Move to the block where IF @c_FinalizeFlag = 'Y'
         -- IF @c_Lottable05Label = 'RCP_DATE' AND (@d_Lottable05 IS NULL)
         -- BEGIN
         --    SELECT @d_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))
         -- END

         IF @c_RecType <> 'GRN' AND @c_Lottable03Label  = 'SUB-INV'
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspGetRight NULL,  -- facility
                    @c_StorerKey,  -- Storerkey
                    @c_Sku,           -- Sku
                    'PopulateSubInv',       -- Configkey
                    @b_success     output,
                    @c_PopulateSubInv   output,
                    @n_err         output,
                    @c_errmsg      output

           IF @b_success <> 1
           BEGIN
              SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
              SELECT @n_err = 60135
           END
           ELSE
           IF @c_PopulateSubInv = '1'
           BEGIN
              -- populate subinventory codes on Lottable03 before finalizing.
              -- Modify By SHONG on 13-Mar-2003
              -- Performance Issues
              SELECT @c_Lottable03 = ISNULL(Facility.Userdefine10, '')
                FROM  FACILITY (NOLOCK)
               WHERE  Facility = @c_Facility
            END
         END

         -- SOS28761
         -- Move to the block where IF @c_FinalizeFlag = 'Y'
         -- IF @c_Lottable03Label = 'RCP_DATE' AND ( dbo.fnc_RTrim(@c_Lottable03) IS NULL OR  dbo.fnc_RTrim(@c_Lottable03) = '')
         -- BEGIN
         --    SELECT @c_Lottable03 = CONVERT(CHAR(10), GETDATE(), 21)  /* yyyy-mm-dd */
         -- END

         IF @c_Lottable04Label = 'GENEXPDATE' AND (@d_Lottable04 IS NULL OR @d_Lottable04 = '19000101')
         BEGIN
            SELECT @d_Lottable04 = CONVERT(DATETIME, '31 dec 2099', 106)   /* yyyy-mm-dd */
         END

         -- Added for IDSV5 by June 25.Jun.02, (extract from IDSHK) *** Start
         IF @n_continue=1 or @n_continue=2
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspGetRight null,  -- facility
                  @c_StorerKey,              -- Storerkey
                  @c_Sku,                    -- Sku
                  'DefaultLottable_Returns', -- Configkey
                  @b_success                   output,
                  @c_DefaultLottable_Returns   output,
                  @n_err                       output,
                  @c_errmsg                    output,
                  @c_DeftLot_Returns_Opt1      output --NJOW04

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
               SELECT @n_err = 60136
            END

            IF @c_RecType <> 'NORMAL' AND @c_RecType <> 'RPO' AND @c_RecType <> 'RRB' AND @c_RecType <> 'TBLRRP'
               AND  @c_DefaultLottable_Returns = '1'
            BEGIN
               IF (@c_Lottable01 IS NULL OR @c_Lottable01 = '') AND
                  (@c_Lottable02 IS NULL OR @c_Lottable02 = '') AND
                  (@c_Lottable03 IS NULL OR @c_Lottable03 = '') AND
                  (@c_Lottable06 IS NULL OR @c_Lottable06 = '') AND        --CS01
                  (@c_Lottable07 IS NULL OR @c_Lottable07 = '') AND        --CS01
                  (@c_Lottable08 IS NULL OR @c_Lottable08 = '') AND        --CS01
                  (@c_Lottable09 IS NULL OR @c_Lottable09 = '') AND        --CS01
                  (@c_Lottable10 IS NULL OR @c_Lottable10 = '') AND        --CS01
                  (@c_Lottable11 IS NULL OR @c_Lottable11 = '') AND        --CS01
                  (@c_Lottable12 IS NULL OR @c_Lottable12 = '')            --CS01
               BEGIN
                  EXEC ispGetOldestLot
                       @c_RecType -- Leong01
                  ,    @c_Facility
                  ,    @c_StorerKey
                  ,    @c_SKU
                  ,    @c_Lottable01   OUTPUT
                  ,    @c_Lottable02   OUTPUT
                  ,    @c_Lottable03   OUTPUT
                  ,    @d_Lottable04   OUTPUT
                  ,    @d_Lottable05   OUTPUT
                  ,    @c_lottable06   OUTPUT         --CS01
                  ,    @c_lottable07   OUTPUT         --CS01
                  ,    @c_lottable08   OUTPUT         --CS01
                  ,    @c_lottable09   OUTPUT         --CS01
                  ,    @c_lottable10   OUTPUT         --CS01
                  ,    @c_lottable11   OUTPUT         --CS01
                  ,    @c_lottable12   OUTPUT         --CS01
                  ,    @d_lottable13   OUTPUT         --CS01
                  ,    @d_lottable14   OUTPUT         --CS01
                  ,    @d_lottable15   OUTPUT         --CS01
                  ,    @b_Success      OUTPUT
                  ,    @n_err          OUTPUT
                  ,    @c_errmsg       OUTPUT

                  --NJOW04
                  IF ISNUMERIC(@c_DeftLot_Returns_Opt1) = 1 AND @d_Lottable05 <> '1900-01-01' AND @d_Lottable05 IS NOT NULL 
                  BEGIN
                      SET @d_Lottable05 = DATEADD(Day, CAST(@c_DeftLot_Returns_Opt1 AS INT), @d_Lottable05)
                  END                                 
               END
            END
         END -- @n_continue=1 or @n_continue=2

         IF @c_DefaultLottable_Returns = '1' -- Added for IDSV5 by June 25.Jun.02, (extract from IDSHK)
         BEGIN
            -- SOS 3333 for HK
            -- for all return receipts (ERR, GRN types), the receipt date (Lottable05) of each sku will be defaulted to 1 day
            -- before the oldest date in the system with the same lot01, lot02, lot03, lot04.
            IF @c_RecType in ('ERR','GRN','RGR','VFEGRN') and @c_Lottable05Label = 'RCP_DATE'  --NJOW03   --WL01
            BEGIN
               IF @d_Lottable04 <= '01/01/1900' OR @d_Lottable04 IS NULL
               BEGIN
                  -- Change by June 10.Jul.03 SOS12281
                  -- select @d_Lottable05 = isnull(min(lotattribute.Lottable05),getdate())
                  SELECT @d_Lottable05 = ISNULL(MIN(lotattribute.Lottable05), CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 106)))
                  FROM lotattribute (NOLOCK)
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
                  SELECT @d_Lottable05 = ISNULL(MIN(lotattribute.Lottable05), CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 106)))
                  FROM lotattribute (NOLOCK)
                  WHERE sku = @c_sku
                  AND storerkey = @c_storerkey
                  AND Lottable01 = @c_Lottable01
                  AND Lottable02 = @c_Lottable02
                  AND Lottable03 = @c_Lottable03
                  AND CONVERT(CHAR(8), Lottable04) = CONVERT(CHAR(8), @d_Lottable04)
               END
               
               --NJOW04
               IF ISNUMERIC(@c_DeftLot_Returns_Opt1) = 1 AND @d_Lottable05 <> '1900-01-01' AND @d_Lottable05 IS NOT NULL AND @@ROWCOUNT > 0
               BEGIN
                  SET @d_Lottable05 = DATEADD(Day, CAST(@c_DeftLot_Returns_Opt1 AS INT), @d_Lottable05)
               END               
            END    -- END SOS 3333
         END   -- Added for IDSV5 by June 25.Jun.02, (extract from IDSHK)
     
          /*CS01 Start*/

         SET @c_skustatusFlag = '0'
         
         SELECT @c_skustatusFlag = C.UDF01
           FROM SKU S WITH (NOLOCK)
           JOIN CODELKUP C WITH (NOLOCK) ON UPPER(c.code) = UPPER(s.skustatus)
          WHERE S.Storerkey = @c_storerkey
            AND S.SKU = @c_Sku
            AND C.listname='SKUStatus'

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
            SELECT @n_err = 60137
         END  
         ELSE IF @c_DisallowInvalidSku = '1'  
         BEGIN  
            IF @c_skustatusFlag = '1'
            BEGIN 
               SELECT @n_continue = 3, @c_errmsg = 'The status for SKU : ' + @c_sku + ' is INACTIVE.Insert Fail'   
               SELECT @n_err = 60138 
            END
         END  
      
         /*CS01 End*/  

         --MC01 - S
         IF ISNULL(RTRIM(@c_Lottable01),'') <> ''
            OR ISNULL(RTRIM(@c_Lottable02),'') <> ''
            OR ISNULL(RTRIM(@c_Lottable03),'') <> ''
            OR ISNULL(RTRIM(@d_Lottable04),'') <> ''
            OR ISNULL(RTRIM(@d_Lottable05),'') <> ''
            OR ISNULL(RTRIM(@c_Lottable06),'') <> ''        --CS01
            OR ISNULL(RTRIM(@c_Lottable07),'') <> ''        --CS01
            OR ISNULL(RTRIM(@c_Lottable08),'') <> ''        --CS01
            OR ISNULL(RTRIM(@c_Lottable09),'') <> ''        --CS01
            OR ISNULL(RTRIM(@c_Lottable10),'') <> ''        --CS01
            OR ISNULL(RTRIM(@c_Lottable11),'') <> ''        --CS01
            OR ISNULL(RTRIM(@c_Lottable12),'') <> ''        --CS01
            OR ISNULL(RTRIM(@d_Lottable13),'') <> ''        --CS01
            OR ISNULL(RTRIM(@d_Lottable14),'') <> ''        --CS01
            OR ISNULL(RTRIM(@d_Lottable15),'') <> ''        --CS01
         BEGIN
            SELECT @b_success = 0
            SET @c_LOTCHGLOG = '0'

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
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
               SELECT @n_err = 60139
            END
            ELSE IF @c_LOTCHGLOG = '1'
            BEGIN
               SELECT @c_PODLottable01 = PODETAIL.Lottable01
                    , @c_PODLottable02 = PODETAIL.Lottable02
                    , @c_PODLottable03 = PODETAIL.Lottable03
                    , @d_PODLottable04 = PODETAIL.Lottable04
                    , @d_PODLottable05 = PODETAIL.Lottable05
                    , @c_PODLottable06 = PODETAIL.Lottable06      --CS01
                    , @c_PODLottable07 = PODETAIL.Lottable07      --CS01
                    , @c_PODLottable08 = PODETAIL.Lottable08      --CS01
                    , @c_PODLottable09 = PODETAIL.Lottable09      --CS01
                    , @c_PODLottable10 = PODETAIL.Lottable10 --CS01
                    , @c_PODLottable11 = PODETAIL.Lottable11      --CS01
                    , @c_PODLottable12 = PODETAIL.Lottable12      --CS01
                    , @d_PODLottable13 = PODETAIL.Lottable13      --CS01
                    , @d_PODLottable14 = PODETAIL.Lottable14      --CS01
                    , @d_PODLottable15 = PODETAIL.Lottable15      --CS01
               FROM   PODETAIL WITH (NOLOCK)
               WHERE  PODETAIL.POKey = @c_POKey
               AND    PODETAIL.POLineNumber = @c_POLineNumber

               IF (ISNULL(@c_PODLottable01,'') <> ISNULL(@c_Lottable01,''))
                  OR (ISNULL(@c_PODLottable02,'') <> ISNULL(@c_Lottable02,''))
                  OR (ISNULL(@c_PODLottable03,'') <> ISNULL(@c_Lottable03,''))
                  OR (ISNULL(@d_PODLottable04,'') <> ISNULL(@d_Lottable04,''))
                  OR (ISNULL(@d_PODLottable05,'') <> ISNULL(@d_Lottable05,''))
                  OR (ISNULL(@c_PODLottable06,'') <> ISNULL(@c_Lottable06,''))         --CS01
                  OR (ISNULL(@c_PODLottable06,'') <> ISNULL(@c_Lottable06,''))         --CS01
                  OR (ISNULL(@c_PODLottable06,'') <> ISNULL(@c_Lottable06,''))         --CS01
                  OR (ISNULL(@c_PODLottable06,'') <> ISNULL(@c_Lottable06,''))         --CS01
                  OR (ISNULL(@c_PODLottable06,'') <> ISNULL(@c_Lottable06,''))         --CS01
                  OR (ISNULL(@c_PODLottable07,'') <> ISNULL(@c_Lottable07,''))         --CS01
                  OR (ISNULL(@c_PODLottable08,'') <> ISNULL(@c_Lottable08,''))         --CS01
                  OR (ISNULL(@c_PODLottable09,'') <> ISNULL(@c_Lottable09,''))         --CS01
                  OR (ISNULL(@c_PODLottable10,'') <> ISNULL(@c_Lottable10,''))         --CS01
                  OR (ISNULL(@c_PODLottable11,'') <> ISNULL(@c_Lottable11,''))         --CS01
                  OR (ISNULL(@c_PODLottable12,'') <> ISNULL(@c_Lottable12,''))         --CS01
                  OR (ISNULL(@d_PODLottable13,'') <> ISNULL(@d_Lottable13,''))         --CS01
                  OR (ISNULL(@d_PODLottable14,'') <> ISNULL(@d_Lottable14,''))         --CS01
                  OR (ISNULL(@d_PODLottable15,'') <> ISNULL(@d_Lottable15,''))         --CS01
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
                     SELECT @n_err = 60140 -- @n_err2
                     SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
                     GOTO QUIT
                  END
                  ELSE
                  BEGIN
                     INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                     VALUES  (@c_TransmitlogKey, 'LOTCHGLOG', @c_ReceiptKey, @c_ReceiptLineNumber, @c_StorerKey, '0')

                     SELECT @n_err= @@Error

                     IF NOT @n_err = 0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @n_err = 60141
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ':  Unable to obtain transmitlogkey (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                                         + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        GOTO QUIT
                     END
                  END
               END  --IF (ISNULL(@c_PODLottable02,'') <> ISNULL(@c_Lottable02,'')) OR (ISNULL(@d_PODLottable04,'') <> ISNULL(@d_Lottable04,''))
            END  --IF @c_LOTCHGLOG = '1'
         END  --IF ISNULL(RTRIM(@c_Lottable02),'') <> '' OR ISNULL(RTRIM(@d_Lottable04),'') <> ''
         --MC01 - E

         IF @c_FinalizeFlag = 'Y'
         BEGIN
            -- SOS28761
            -- Set default receipt date if Lottable03 and Lottable05 is null after finalized
            IF @c_Lottable03Label = 'RCP_DATE' AND ( dbo.fnc_RTrim(@c_Lottable03) IS NULL OR  dbo.fnc_RTrim(@c_Lottable03) = '')
            BEGIN
               SELECT @c_Lottable03 = CONVERT(CHAR(10), GETDATE(), 21)  /* yyyy-mm-dd */
            END

            IF @c_Lottable05Label = 'RCP_DATE' AND (@d_Lottable05 IS NULL)
            BEGIN
               SELECT @d_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable01Label)) > '' AND (@c_Lottable01 IS NULL OR @c_Lottable01 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE01' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60142
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable01 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable01Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02Label)) > '' AND (@c_Lottable02 IS NULL OR @c_Lottable02 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE02' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60143
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable02 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable03Label)) > '' AND (@c_Lottable03 IS NULL OR @c_Lottable03 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE03' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60144
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable03 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable03Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable04Label)) > '' AND (@d_Lottable04 <= '01/01/1900' OR @d_Lottable04 IS NULL)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE04' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60145
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable04 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable04Label)) + ' REQUIRED'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable05Label)) > '' AND (@d_Lottable05 <= '01/01/1900' OR @d_Lottable05 IS NULL)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE05' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60146
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable05 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable05Label)) + ' REQUIRED'
                  BREAK
               END
            END

           /*CS01 start*/

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable06Label)) > '' AND (@c_Lottable06 IS NULL OR @c_Lottable06 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE06' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60147
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable06 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable06Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable07Label)) > '' AND (@c_Lottable07 IS NULL OR @c_Lottable07 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE07' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60148
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable07= ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable07Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable08Label)) > '' AND (@c_Lottable08 IS NULL OR @c_Lottable08= '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE08' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60149
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable08 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable08Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable09Label)) > '' AND (@c_Lottable09 IS NULL OR @c_Lottable09 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE09' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60150
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable09 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable09Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable10Label)) > '' AND (@c_Lottable10 IS NULL OR @c_Lottable10 = '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE10' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60151
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable10= ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable10Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable11Label)) > '' AND (@c_Lottable11 IS NULL OR @c_Lottable11= '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE11' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60152
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable11 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable11Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable12Label)) > '' AND (@c_Lottable12 IS NULL OR @c_Lottable12= '')
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE12' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60153
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable12 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable12Label)) + ' REQUIRED!'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable13Label)) > '' AND (@d_Lottable13 <= '01/01/1900' OR @d_Lottable13 IS NULL)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE13' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60154
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable13 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable13Label)) + ' REQUIRED'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable14Label)) > '' AND (@d_Lottable14 <= '01/01/1900' OR @d_Lottable14 IS NULL)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE14' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60155
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable14 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable14Label)) + ' REQUIRED'
                  BREAK
               END
            END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable15Label)) > '' AND (@d_Lottable15 <= '01/01/1900' OR @d_Lottable15 IS NULL)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE15' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60156
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable15 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable15Label)) + ' REQUIRED'
                  BREAK
               END
            END

           /*CS01 End*/

            SELECT @b_success = 0
            EXECUTE nspGetRight null,  -- facility
               @c_StorerKey,  -- Storerkey
               @c_SKU,           -- Sku
               'ExpiredReason',        -- Configkey
               @b_success               output,
               @c_authority_ExpReason   output,
               @n_err                   output,
               @c_errmsg                output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
               SELECT @n_err = 60157
            END
            ELSE IF @c_authority_ExpReason = '1'
            BEGIN -- Added for IDSV5 by June 25.Jun.02, (Extract from IDSHK) ***
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
                     SELECT @n_err = 60158
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Product is due to expire for Detail Line: ' 
                                      + Convert(CHAR(5), SUBSTRING(@ReceiptPrimaryKey, 11, 5) ) + '. Sub-Reason code required ((ntrReceiptDetailAdd))'
                     BREAK
                  END
               END
            END  -- END - Reasoncode required for receipt of expired products

            SELECT @b_success = 0

            EXECUTE nspGetRight @c_Facility,
                  @c_storerkey,
                  @c_sku,
                  'Allow_OverReceipt', -- Configkey
                  @b_success             output,
                  @c_authority_OverRcp   output,
                  @n_err                 output,
                  @c_errmsg              output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
               SELECT @n_err = 60159
            END
            ELSE -- Success = 1
            BEGIN
               IF @c_authority_OverRcp <> '1'
               BEGIN
                  IF @n_TotQtyReceived > @n_QtyExpected
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60160
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) 
                                      + ': Insert Failed on Table ReceiptDetail (ntrReceiptDetailAdd) - CANNOT RECEIVE MORE THAN EXPECTED...'
                     BREAK
                  END
               END
               ELSE
               BEGIN -- Allow OverReceipt
                  SELECT @b_success = 0

                  EXECUTE nspGetRight
                        --null, -- Facility SOS# 115735
                        @c_Facility, -- SOS#115735
                        @c_Storerkey,
                        null,
                        'ByPassTolerance',
                        @b_success           output,
                        @c_ByPassTolerance   output,
                        @n_err               output,
                        @c_errmsg            output

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
                     SELECT @n_err = 60161
                  END
                  ELSE -- Success = 1
                  IF @c_ByPassTolerance <> '1'
                  BEGIN
                     IF (@n_TotQtyReceived) > (@n_QtyExpected * (1 + (@n_TolerancePerc * 0.01)))
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60162 --63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) 
                                         + ': Insert Failed on Table ReceiptDetail (ntrReceiptDetailAdd) - Qty Received More Exceed Tolerance ...'
                        BREAK
                     END
                  END
               END
            END
         -- END Check Tolerance n Over receive

            SELECT @b_success = 0
            EXECUTE nspGetRight null,
                  @c_StorerKey,
                  @c_Sku,
                  'Return Validation',
                  @b_success             output,
                  @c_Authority_RtnValid  output,
                  @n_err                 output,
                  @c_errmsg              output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
               SELECT @n_err = 60163
            END
            ELSE IF @c_Authority_RtnValid = '1'
            BEGIN
               IF @c_RECTYPE <> 'RPO' AND @c_RECTYPE <> 'RRB' AND @c_RECTYPE <> 'NORMAL' AND @c_RECTYPE <> 'TBLRRP'
               AND  ( dbo.fnc_RTrim(@c_SubReasonCode) = '' OR dbo.fnc_RTrim(@c_SubReasonCode) IS NULL )
               BEGIN
                  SELECT @c_errmsg = 'VALIDATION ERROR: ASN Detail Sub-Reason Code Required.'
                  SELECT @n_err = 60164
               END
            END

            -- SOS28761
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               UPDATE RECEIPTDETAIL
                  SET Lottable01 = @c_Lottable01,
                      Lottable02 = @c_Lottable02,
                      Lottable03 = @c_Lottable03,
                      Lottable04 = @d_Lottable04,
                      Lottable05 = @d_Lottable05,
                      Lottable06 = @c_Lottable06,        --CS01
                      Lottable07 = @c_Lottable07,        --CS01
                      Lottable08 = @c_Lottable08,        --CS01
                      Lottable09 = @c_Lottable09,        --CS01
                      Lottable10 = @c_Lottable10,        --CS01
                      Lottable11 = @c_Lottable11,        --CS01
                      Lottable12 = @c_Lottable12,        --CS01
                      Lottable13 = @d_Lottable13,        --CS01
                      Lottable14 = @d_Lottable14,        --CS01
                      Lottable15 = @d_Lottable15,        --CS01
                      BeforeReceivedQty = CASE WHEN BeforeReceivedQty < @n_TotQtyReceived THEN
                                               @n_TotQtyReceived
                                          ELSE BeforeReceivedQty
                                          END,
                      TrafficCop = NULL
               WHERE RECEIPTDETAIL.Receiptkey = SUBSTRING(@ReceiptPrimaryKey, 1, 10)
               AND   RECEIPTDETAIL.RECEIPTLINENUMBER = SUBSTRING(@ReceiptPrimaryKey, 11, 5)

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60165
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err ) + ': Update Failed On Table RECEIPTDETAIL. (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END

            --TK02 - Start
            SELECT @b_success = 0

            EXECUTE nspGetRight null,
                     @c_StorerKey,
                     '',
                     'PopulatePalletLabel',
                     @b_success              output,
                     @c_PopPalletLabel     output,
                     @n_err                  output,
                     @c_errmsg               output
         
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
               SELECT @n_err = 60166
            END
            ELSE IF @c_PopPalletLabel = '1'
            BEGIN
               --(BL01) Start
               --Only insert when not exist.
               --IF NOT EXISTS (SELECT 1 FROM PalletLabel (NOLOCK) WHERE ID = @c_ToID AND Status NOT IN ('X','9'))
               --BEGIN
               --   --Insert the required pallet label data for later putaway and print processing.
               --   INSERT INTO PalletLabel (ID, Tablename, HDKey, DTKey, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10) 
               --   VALUES (@c_ToID, 'RECEIPT', @c_ReceiptKey, @c_ReceiptLineNumber, '','','','','',  '','','','','')
               --END
            -- (BL01) End
         
               --If exist.
               --IF EXISTS (SELECT 1 FROM PalletLabel (NOLOCK) WHERE ID = @c_ToID AND Status NOT IN ('X','9'))
               --BEGIN

               --set old record to x
               --UPDATE PalletLabel WITH (ROWLOCK) SET Status = 'X' WHERE ID = @c_ToID AND Status NOT IN ('X','9')
                         
               --END
            
               --Delete old record   (JH01) Start         
               Delete From PalletLabel WHERE ID = @c_ToID   
               --Insert the required pallet label data for later putaway and print processing.
               INSERT INTO PalletLabel (ID, Tablename, HDKey, DTKey, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10) 
               VALUES (@c_ToID, 'RECEIPT', @c_ReceiptKey, @c_ReceiptLineNumber, '','','','','', '','','','','')
               --(JH01)  End
            END
            --TK02 - End
         END -- FinalizeFlag = 'Y'

         IF (@n_continue = 1 OR @n_continue = 2) And @c_FinalizeFlag = 'Y'
         BEGIN
            EXECUTE nspItrnAddDeposit
            @n_ItrnSysId    = @n_ItrnSysId ,
            @c_StorerKey    = @c_StorerKey ,
            @c_Sku          = @c_Sku       ,
            @c_Lot          = @c_Lot       ,
            @c_ToLoc        = @c_ToLoc     ,
            @c_ToID         = @c_ToID      ,
            @c_Status       = @c_Status    ,
            @c_lottable01   = @c_lottable01,
            @c_lottable02   = @c_lottable02,
            @c_lottable03   = @c_lottable03,
            @d_lottable04   = @d_lottable04,
            @d_lottable05   = @d_lottable05,
            @c_lottable06   = @c_lottable06,    --CS01
            @c_lottable07   = @c_lottable07,    --CS01
            @c_lottable08   = @c_lottable08,    --CS01
            @c_lottable09   = @c_lottable09,    --CS01
            @c_lottable10   = @c_lottable10,    --CS01
            @c_lottable11   = @c_lottable11,    --CS01
            @c_lottable12   = @c_lottable12,    --CS01
            @d_lottable13   = @d_lottable13,    --CS01
            @d_lottable14   = @d_lottable14,    --CS01
            @d_lottable15   = @d_lottable15,    --CS01
            @c_Channel      = @c_Channel,    -- (SWT02)
            @n_Channel_ID   = @n_Channel_ID, -- (SWT02)  
            @c_PalletType   = @c_PalletType, -- (Wan01) 
            @n_casecnt      = @n_casecnt   ,
            @n_innerpack    = @n_innerpack ,         
            @n_qty          = @n_Qty       ,
            @n_pallet       = @n_pallet    ,
            @f_cube         = @f_cube      ,
            @f_grosswgt     = @f_grosswgt  ,
            @f_netwgt       = @f_netwgt    ,
            @f_otherunit1   = @f_otherunit1,
            @f_otherunit2   = @f_otherunit2,
            @c_SourceKey    = @c_SourceKey ,
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
               BREAK
            END
            ELSE
            BEGIN
               -- Added for IDSV5 by June 25.Jun.02, (extract from IDSMY) *** Start
               SELECT @b_success = 0
               EXECUTE nspGetRight null,  -- facility
                     @c_StorerKey,  -- Storerkey
                     @c_Sku,           -- Sku
                     'FUJIASNREFNO',  -- Configkey
                     @b_success     output,
                     @c_authority   output,
                     @n_err         output,
                     @c_errmsg      output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60167
               END
               ELSE IF @c_authority = '1'
               BEGIN -- Added for IDSV5 by June 25.Jun.02, (extract from IDSMY) ***
                  /* --- CREATE SERIES KEY FOR FUJI ASN on carrierreference --- */
                  -- added 03.10.00 wally
                  IF @c_StorerKey = 'FUJI'
                  BEGIN
                     DECLARE @c_insert_finalize NVARCHAR(1),
                             @c_delete_finalize NVARCHAR(1),
                             @c_key int

                     IF @c_RecType = 'NORMAL'
                     BEGIN
                        SELECT @c_key = ISNULL(MAX(CONVERT(INT, RIGHT(RECEIPT.carrierreference, 8))), 0) + 1
                        FROM RECEIPT (NOLOCK)
                        WHERE rectype = @c_RecType
                        AND storerkey = 'FUJI'

                        UPDATE RECEIPT
                        SET RECEIPT.trafficcop = null,
                        RECEIPT.carrierreference = 'GR' + REPLICATE('0', 8 - LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key))))) + dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key)))
                        FROM RECEIPT, INSERTED
                        WHERE RECEIPT.receiptkey = INSERTED.receiptkey
                        AND RECEIPT.carrierreference IS NULL
                     END
                     ELSE
                     BEGIN
                        SELECT @c_key = ISNULL(MAX(CONVERT(INT, RIGHT(RECEIPT.carrierreference, 8))), 0) + 1
                        FROM RECEIPT (NOLOCK)
                        WHERE rectype <> 'NORMAL'
                        AND storerkey = 'FUJI'

                        UPDATE RECEIPT
                        SET RECEIPT.trafficcop = null,
                        RECEIPT.carrierreference = 'TR' + REPLICATE('0', 8 - LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key))))) + dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(8), @c_key)))
                        FROM RECEIPT (NOLOCK), INSERTED
                        WHERE RECEIPT.receiptkey = INSERTED.receiptkey
                        AND RECEIPT.carrierreference IS NULL
                     END
                  END -- @c_StorerKey = 'FUJI'
               END -- Authority = 1
            END -- Itrn Add Successful
         END -- @n_continue = 1 OR @n_continue = 2 And @c_FinalizeFlag = 'Y'
      END -- While
   END -- @n_continue = 1 or @n_continue=2

   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,03,0,RECEIPT Update                                    ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END

      DECLARE @n_insertedcount int
      SELECT @n_insertedcount = (select count(*) FROM inserted)

      IF @n_insertedcount = 1
      BEGIN
         UPDATE RECEIPT
         SET  RECEIPT.OpenQty = RECEIPT.OpenQty + ((INSERTED.QtyExpected+INSERTED.FreeGoodQtyExpected) - INSERTED.QtyReceived)
         FROM RECEIPT,
         INSERTED
         WHERE     RECEIPT.ReceiptKey = INSERTED.ReceiptKey
      END
      ELSE
      BEGIN
         UPDATE RECEIPT SET RECEIPT.OpenQty
                          = (Select Sum(ReceiptDetail.QtyExpected - ReceiptDetail.QtyReceived) From RECEIPTDETAIL
         Where RECEIPTDETAIL.Receiptkey = RECEIPT.Receiptkey)
         FROM RECEIPT,INSERTED
         WHERE RECEIPT.Receiptkey IN (Select Distinct Receiptkey From Inserted)
         AND RECEIPT.Receiptkey = Inserted.Receiptkey
      END

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert failed on table RECEIPT. (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60168
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Zero rows affected updating table RECEIPT. (ntrReceiptDetailAdd) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   -- (YokeBeen02) - Start
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)
                   JOIN INSERTED ON (INSERTED.RECEIPTKey = RECEIPT.RECEIPTKey)
                  WHERE (RECEIPT.ASNStatus = '0' 
                         OR RECEIPT.ASNStatus IN (SELECT Code FROM CODELKUP(NOLOCK) 
                                                  WHERE Listname = 'ASNSTSTO1'
                                                  AND Storerkey = RECEIPT.Storerkey)) --NJOW05
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
                                         AND Storerkey = RECEIPT.Storerkey)) --NJOW05

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue=3
            SELECT @n_err = 60169
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update failed on table RECEIPT. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='
                              + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END  -- IF record exists 
   END  -- IF @n_continue = 1 or @n_continue=2
   -- (YokeBeen02) - End

   QUIT:

   /* #INCLUDE <TRRDA2.SQL> */
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
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END

         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrReceiptDetailAdd'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,637,00,9,ntrReceiptDetailAdd Tigger                       ,' + CONVERT(char(12), getdate(), 114)
            PRINT @profiler
         END
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,00,9,ntrReceiptDetailAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114) PRINT @profiler
      END
      RETURN
   END
END

GO