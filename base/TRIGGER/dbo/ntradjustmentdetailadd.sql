SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Trigger: ntrAdjustmentDetailAdd                                             */
/* Creation Date:                                                              */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:                                                                    */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Called By: When records add into AdjustmentDetail                           */
/*                                                                             */
/* PVCS Version: 1.9                                                           */
/*                                                                             */
/* Version: 5.4                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/*                                                                             */
/* Updates:                                                                    */
/* Date         Author       Ver.   Purposes                                   */
/* 30-Aug-2004  Shong        1.0    Move from Branch                           */
/* 30-Jun-2005  Shong        1.0    Check Finalize option by Storer            */
/* 19-Oct-2006  MaryVong     1.0    Add in RDT compatible error messages       */
/* 28-Jun-2007  MaryVong     1.0    Remove dbo.fnc_RTRIM and dbo.fnc_LTRIM     */
/* 05-Jul-2007  Shong        1.0    SOS75806 - UCC Adjustment                  */
/* 24-Mar-2010  YokeBeen     1.1    SOS#165421 - New Trigger point - "OWADJWO" */
/*                                  for WMS-E1 Work Order process.             */
/*                                  - (YokeBeen01)                             */
/* 31-Jan-2011  YTWan        1.2    Adjustment Status Control. (Wan01)         */
/* 05-Sep-2013  NJOW01       1.3    288779-fix to skip update UCC if adj create*/
/*                                  from CC UCC adj posting                    */
/* 07-May-2014  TKLIM        1.4    Added Lottables 06-15                      */
/* 28-Sep-2016  Leong        1.5    Skip trigger if ArchiveCop = '9'.          */
/* 27-Jul-2017  TLTING       1.6    Remove SETROWCOUNT                         */
/* 06-Feb-2018  SWT02        1.7    Added Channel Management Logic             */
/* 23-JUL-2019  Wan02        1.8    WMS-9872 - CN_NIKESDC_Exceed_Channel       */
/* 01-Jun-2020  Wan03        1.9    WMS-13117 - [CN] Sephora_WMS_ITRN_Add_UCC_CR*/
/*******************************************************************************/

CREATE TRIGGER [dbo].[ntrAdjustmentDetailAdd]
ON  [dbo].[ADJUSTMENTDETAIL]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS oFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                int       -- Error number returned by stored procedure or this trigger
         , @n_err2               int       -- For Additional Error Detection
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue           int
         , @n_starttcnt          int       -- Holds the current transaction count
         , @c_preprocess         NVARCHAR(250) -- preprocess
         , @c_pstprocess         NVARCHAR(250) -- post process
         , @n_cnt                int

   DECLARE @c_authority_OWITF    NVARCHAR(1)   -- (YokeBeen01)
         , @c_authority_OWADJWO  NVARCHAR(1)   -- (YokeBeen01)
         , @c_cckey              NVARCHAR(10)  -- NJOW01

   DECLARE @c_UCCStatus          NVARCHAR(10) = '' --(Wan03)

   SELECT @n_continue=1, @n_starttcnt = @@TRANCOUNT
   /* #INCLUDE <TRADA1.SQL> */
  
   -- To Skip all the trigger process when Insert the history records from Archive as user request
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_FinalizeAdjustment NVARCHAR(1) -- Flag to see if overallocations are allowed.
      DECLARE @c_StorerKey NVARCHAR(15), 
              @c_Facility  NVARCHAR(10)
              
            , @c_ChannelInventoryMgmt      NVARCHAR(10) = '0' -- (SWT02)
            
      SELECT TOP 1
             @c_StorerKey = INSERTED.StorerKey, 
             @c_Facility  = LOC.Facility 
      FROM   INSERTED 
      JOIN   LOC WITH (NOLOCK) ON LOC.LOC = INSERTED.LOC 

      SELECT @b_success = 0
      EXECUTE nspGetRight
               NULL,                    -- Facility
               @c_StorerKey,            -- Storer
               NULL,                    -- No Sku in this Case
               'FinalizeAdjustment',    -- ConfigKey
               @b_success               output,
               @c_FinalizeAdjustment    output,
               @n_err                   output,
               @c_errmsg                output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                          + ': Retrieve Failed On GetRight (FinalizeAdjustment). (ntrAdjustmentDetailAdd)'
      END

      --(Wan01) - START
      IF @n_continue=1 or @n_continue=2
      BEGIN
         DECLARE @c_ADJStatusCtrl      NVARCHAR(10)

         SET @c_ADJStatusCtrl = ''
         SET @b_success = 0
         EXECUTE nspGetRight
                  NULL                     -- Facility
                , @c_StorerKey             -- Storer
                , NULL                     -- No Sku in this Case
                , 'AdjStatusControl'       -- ConfigKey
                , @b_success               OUTPUT
                , @c_ADJStatusCtrl         OUTPUT
                , @n_err                   OUTPUT
                , @c_errmsg                OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62702  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Retrieve Failed On GetRight (AdjStatusControl). (ntrAdjustmentDetailAdd)'
         END
      END
      --(Wan01) - END

      IF @c_FinalizeAdjustment = '1' OR @c_ADJStatusCtrl = '1'                                     --(Wan01)
      BEGIN
         SELECT @n_continue = '4'
      END

      -- (Wan02) - START
      -- (SWT02)
      --SET @c_ChannelInventoryMgmt = '0'
      --If @n_continue = 1 or @n_continue = 2
      --Begin
      --   Select @b_success = 0
      --   Execute nspGetRight      
      --   @c_facility,
      --   @c_StorerKey,           -- Storer
      --   '',                     -- Sku
      --   'ChannelInventoryMgmt', -- ConfigKey
      --   @b_success    output,
      --   @c_ChannelInventoryMgmt  output,
      --   @n_err        output,
      --   @c_errmsg     output
      --   If @b_success <> 1
      --   Begin
      --      Select @n_continue = 3, @n_err = 61961, @c_errmsg = 'nspItrnAddAdjustmentCheck:' + ISNULL(RTRIM(@c_errmsg),'')
      --   End
      --END      
       
   END -- IF @n_continue=1 or @n_continue=2

   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE  @c_ADJ_AdjustmentKey        NVARCHAR(10)
             , @c_ADJ_AdjustmentLineNumber NVARCHAR(5)
             , @c_ADJ_StorerKey            NVARCHAR(15)
             , @c_ADJ_Sku                  NVARCHAR(20)
             , @c_ADJ_Loc                  NVARCHAR(10)
             , @c_ADJ_Lot                  NVARCHAR(10)
             , @c_ADJ_Id                   NVARCHAR(18)
             , @c_ADJ_ReasonCode           NVARCHAR(10)
             , @n_ADJ_Qty                  int
             , @n_ADJ_CaseCnt              int
             , @n_ADJ_InnerPack            int
             , @n_ADJ_Pallet               int
             , @n_ADJ_Cube                 float
             , @n_ADJ_GrossWgt             float
             , @n_ADJ_NetWgt               float
             , @n_ADJ_OtherUnit1           float
             , @n_ADJ_OtherUnit2           float
             , @c_ADJ_packkey              NVARCHAR(10)
             , @c_ADJ_uom                  NVARCHAR(10)
             , @d_ADJ_EffectiveDate        datetime
             , @c_ItrnKey                  NVARCHAR(10)
             , @c_SourceKey                NVARCHAR(15)
             , @c_AdjustmentKey            NVARCHAR(10)
             , @c_AdjustmentLineNumber     NVARCHAR(5)
             , @c_ADJ_UCCNo                NVARCHAR(20)  -- SOS75806
             , @c_Channel                  NVARCHAR(20) = '' --(SWT02)
             , @n_Channel_ID               BIGINT = 0 --(SWT02)
 
      DECLARE  @c_lottable01     NVARCHAR(18)   -- Lot lottable01
            ,  @c_lottable02     NVARCHAR(18)   -- Lot lottable02
            ,  @c_lottable03     NVARCHAR(18)   -- Lot lottable03
            ,  @d_lottable04     DATETIME       -- Lot lottable04
            ,  @d_lottable05     DATETIME       -- Lot lottable05
            ,  @c_Lottable06     NVARCHAR(30)
            ,  @c_Lottable07     NVARCHAR(30)
            ,  @c_Lottable08     NVARCHAR(30)
            ,  @c_Lottable09     NVARCHAR(30)
            ,  @c_Lottable10     NVARCHAR(30)
            ,  @c_Lottable11     NVARCHAR(30)
            ,  @c_Lottable12     NVARCHAR(30)
            ,  @d_Lottable13     DATETIME
            ,  @d_Lottable14     DATETIME
            ,  @d_Lottable15     DATETIME
                             
      SELECT @c_ADJ_AdjustmentKey = SPACE(10)
      WHILE (1=1)
      BEGIN
         SELECT TOP 1 @c_ADJ_AdjustmentKey = AdjustmentKey
           FROM INSERTED
          WHERE AdjustmentKey > @c_ADJ_AdjustmentKey
          ORDER BY AdjustmentKey

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         --(Wan02) - START
         SET @c_ChannelInventoryMgmt = ''
         SELECT TOP 1 @c_ChannelInventoryMgmt = SC.Authority
         FROM ADJUSTMENT ADJ WITH (NOLOCK)
         CROSS APPLY fnc_SelectGetRight (ADJ.facility, ADJ.StorerKey, '', 'ChannelInventoryMgmt') SC
         WHERE ADJ.AdjustmentKey = @c_ADJ_AdjustmentKey
         --(Wan02) - END

         --NJOW01
         SET @c_cckey = ''
         SELECT TOP 1 @c_cckey = StockTakeSheetParameters.StockTakeKey
         FROM ADJUSTMENT (NOLOCK)
         JOIN StockTakeSheetParameters (NOLOCK) ON ADJUSTMENT.CustomerRefNo = StockTakeSheetParameters.StockTakeKey
         WHERE ADJUSTMENT.Adjustmentkey = @c_ADJ_AdjustmentKey

         SELECT @c_ADJ_AdjustmentLineNumber = SPACE(5)
         WHILE (1=1)
         BEGIN
            SELECT TOP 1 @c_ADJ_AdjustmentKey  = AdjustmentKey
                 , @c_ADJ_AdjustmentLineNumber = AdjustmentLineNumber
                 , @c_ADJ_StorerKey            = StorerKey
                 , @c_ADJ_Sku                  = Sku
                 , @c_ADJ_Loc                  = Loc
                 , @c_ADJ_Lot                  = Lot
                 , @c_ADJ_Id                   = Id
                 , @c_ADJ_ReasonCode           = ReasonCode
                 , @n_ADJ_Qty                  = Qty
                 , @n_ADJ_CaseCnt              = CaseCnt
                 , @n_ADJ_InnerPack            = InnerPack
                 , @n_ADJ_Pallet               = Pallet
                 , @n_ADJ_Cube                 = Cube
                 , @n_ADJ_GrossWgt             = GrossWgt
                 , @n_ADJ_NetWgt               = NetWgt
                 , @n_ADJ_OtherUnit1           = OtherUnit1
                 , @n_ADJ_OtherUnit2           = OtherUnit2
                 , @c_ADJ_packkey              = Packkey
                 , @c_ADJ_uom                  = UOM
                 , @d_ADJ_EffectiveDate        = EffectiveDate
                 , @c_ItrnKey                  = ItrnKey
                 , @c_ADJ_UCCNo                = ISNULL(INSERTED.UCCNo, '') -- SOS75806
                 , @c_Channel                  = INSERTED.Channel    --(SWT02)
                 , @n_Channel_ID               = INSERTED.Channel_ID --(SWT02)
              FROM INSERTED
             WHERE AdjustmentKey = @c_ADJ_AdjustmentKey
               AND AdjustmentLineNumber > @c_ADJ_AdjustmentLineNumber
             ORDER BY AdjustmentKey,AdjustmentLineNumber

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
            -- Add by June 29.Jan.02
            -- HK Phase II : To Update Itrn's lottable details

            IF @c_ChannelInventoryMgmt = '1'
            BEGIN
               IF ISNULL(RTRIM(@c_Channel),'') = ''
               BEGIN
                   SELECT @n_err = 70001
                   SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Channel Management Enabled, Channel Cannot be BLANK. (ntrAdjustmentDetailAdd)"
                   Select @n_continue = 3
                   BREAK                                 
               END
            END   

            --(Wan03) - START
            IF @c_ADJ_UCCNo <> ''
            BEGIN
               SET @c_UCCStatus = ''
               SELECT TOP 1 @c_UCCStatus = UCC.[Status]
               FROM UCC WITH (NOLOCK)
               WHERE UCC.Storerkey = @c_ADJ_Storerkey
               AND   UCC.UCCNo = @c_ADJ_UCCNo
               AND   UCC.Sku = @c_ADJ_Sku
               AND   UCC.Lot = @c_ADJ_lot
               AND   UCC.Loc = @c_ADJ_loc
               AND   UCC.ID  = @c_ADJ_ID
            END
            --(Wan03) - END
            
            SELECT   @c_lottable01 = lottable01
                  ,  @c_lottable02 = lottable02
                  ,  @c_lottable03 = lottable03
                  ,  @d_lottable04 = lottable04
                  ,  @d_lottable05 = lottable05
                  ,  @c_lottable06 = lottable06
                  ,  @c_lottable07 = lottable07
                  ,  @c_lottable08 = lottable08
                  ,  @c_lottable09 = lottable09
                  ,  @c_lottable10 = lottable10
                  ,  @c_lottable11 = lottable11
                  ,  @c_lottable12 = lottable12
                  ,  @d_lottable13 = lottable13
                  ,  @d_lottable14 = lottable14
                  ,  @d_lottable15 = lottable15
              FROM LOTATTRIBUTE WITH (NOLOCK)
             WHERE Lot = @c_ADJ_lot

            -- End - Add by June 29.Jan.02
            SELECT @c_SourceKey = dbo.fnc_LTRIM(dbo.fnc_RTrim((@c_ADJ_AdjustmentKey)))
                                + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_ADJ_AdjustmentLineNumber))
            SELECT @b_success = 0

            EXECUTE  nspItrnAddAdjustment
                     @n_ItrnSysId     = NULL,
                     @c_StorerKey     = @c_ADJ_StorerKey,
                     @c_Sku           = @c_ADJ_Sku,
                     @c_Lot           = @c_ADJ_Lot,
                     @c_ToLoc         = @c_ADJ_Loc,
                     @c_ToID          = @c_ADJ_Id,
                     @c_Status        = '',
                     @c_lottable01    = @c_lottable01, -- Changed by June 29.Jan.02
                     @c_lottable02    = @c_lottable02, -- Changed by June 29.Jan.02
                     @c_lottable03    = @c_lottable03, -- Changed by June 29.Jan.02
                     @d_lottable04    = @d_lottable04, -- Changed by June 29.Jan.02
                     @d_lottable05    = @d_lottable05, -- Changed by June 29.Jan.02
                     @c_lottable06    = @c_lottable06,
                     @c_lottable07    = @c_lottable07,
                     @c_lottable08    = @c_lottable08,
                     @c_lottable09    = @c_lottable09,
                     @c_lottable10    = @c_lottable10,
                     @c_lottable11    = @c_lottable11,
                     @c_lottable12    = @c_lottable12,
                     @d_lottable13    = @d_lottable13,
                     @d_lottable14    = @d_lottable14,
                     @d_lottable15    = @d_lottable15,
                     @c_Channel       = @c_Channel, 
                     @n_Channel_ID    = @n_Channel_ID,
                     @n_casecnt       = @n_ADJ_CaseCnt,
                     @n_innerpack     = @n_ADJ_InnerPack,
                     @n_qty           = @n_ADJ_Qty,
                     @n_pallet        = @n_ADJ_Pallet,
                     @f_cube          = @n_ADJ_Cube,
                     @f_grosswgt      = @n_ADJ_GrossWgt,
                     @f_netwgt        = @n_ADJ_NetWgt,
                     @f_otherunit1    = @n_ADJ_OtherUnit1,
                     @f_otherunit2    = @n_ADJ_OtherUnit2,
                     @c_SourceKey     = @c_SourceKey,
                     @c_SourceType    = 'ntrAdjustmentDetailAdd',
                     @c_PackKey       = @c_AdJ_packkey,
                     @c_UOM           = @c_ADJ_uom,
                     @b_UOMCalc       = 0,
                     @d_EffectiveDate = @d_ADJ_EffectiveDate,
                     @c_itrnkey       = @c_ItrnKey OUTPUT,
                     @b_Success       = @b_Success OUTPUT,
                     @n_err           = @n_err     OUTPUT,
                     @c_errmsg        = @c_errmsg  OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3 /* Other Error flags Set By nspItrnAddAdjustment */
               BREAK
            END
            ELSE
            BEGIN
               -- SOS75806 UCC Adjustment
               IF @c_ADJ_UCCNo <> ''
               BEGIN
                  IF NOT EXISTS( SELECT 1 FROM UCC WITH (NOLOCK)
                                  WHERE StorerKey = @c_ADJ_StorerKey AND UCCNo = @c_ADJ_UCCNo)
                  BEGIN
                     INSERT INTO UCC (UCCNo, Storerkey, ExternKey, SKU, qty, Sourcekey,
                                      Sourcetype, Status, Lot, Loc, Id)
                     VALUES (@c_ADJ_UCCNo, @c_ADJ_StorerKey, '', @c_ADJ_Sku, @n_ADJ_Qty, @c_SourceKey,
                    'ADJUSTMENT', '1', @c_ADJ_Lot, @c_ADJ_Loc, @c_ADJ_ID)

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 62703 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                         + ': Insert Failed On Table UCC. (ntrAdjustmentDetailAdd)'
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                      IF ISNULL(@c_cckey,'') = '' --NJOW01
                      BEGIN
                        UPDATE UCC WITH (ROWLOCK)
                           SET Qty = Qty + @n_ADJ_Qty,
                               Lot = @c_ADJ_Lot,
                               LOC = @c_ADJ_Loc,
                               ID  = @c_ADJ_ID,
                               Status = CASE WHEN (Qty + @n_ADJ_Qty) = 0 THEN '0'
                                             ELSE '1'
                                        END
                         WHERE StorerKey = @c_ADJ_StorerKey
                           AND UCCNo = @c_ADJ_UCCNo
                           AND Status IN ('0','1')

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 62704 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                            + ': Update Failed On Table UCC. (ntrAdjustmentDetailAdd)'
                           BREAK
                        END
                     END
                  END

                  EXEC isp_ItrnUCCAdd
                       @c_Storerkey       = @c_ADJ_StorerKey 
                     , @c_UCCNo           = @c_ADJ_UCCNo     
                     , @c_Sku             = @c_ADJ_Sku  
                     , @c_UCCStatus       = @c_UCCStatus            
                     , @c_SourceKey       = @c_Sourcekey         
                     , @c_ItrnSourceType  = 'ntrAdjustmentDetailAdd' 
                     , @c_ToStorerkey     = '' 
                     , @c_ToUCCNo         = ''     
                     , @c_ToSku           = ''  
                     , @c_ToUCCStatus     = ''                         
                     , @b_Success         = @b_Success          OUTPUT
                     , @n_Err             = @n_Err              OUTPUT
                     , @c_ErrMsg          = @c_ErrMsg           OUTPUT

                  IF @b_Success <> 1  
                  BEGIN
                     SET @n_continue = 3     
                     SET @n_err = 62709 
                     SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Add ITRN UCC Fail. (isp_FinalizeADJ)' 
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
                     ROLLBACK TRAN
                     BREAK
                  END
               END -- IF @c_ADJ_UCCNo <> ''
            END -- IF @b_success = 1

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
                  SET TrafficCop = NULL,
                      ItrnKey = @c_itrnkey,
                      AddDate = GETDATE(),
                      AddWho  = suser_sname(),
                      EditDate = GETDATE(),
                      EditWho = suser_sname(),
                      FinalizedFlag = 'Y'
                WHERE AdjustmentKey = @c_ADJ_AdjustmentKey
                  AND AdjustmentLineNumber = @c_ADJ_AdjustmentLineNumber

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62705 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                   + ': Update Failed On Table ADJUSTMENTDETAIL. (ntrAdjustmentDetailAdd)'
                  BREAK
               END
               IF @n_cnt = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62706 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                   + ': No record updated into Table ADJUSTMENTDETAIL. (ntrAdjustmentDetailAdd)'
                  BREAK
               END
            END -- IF @n_continue = 1 OR @n_continue = 2

            -- (YokeBeen01) - Start
            SELECT @b_success = 0
            EXECUTE nspGetRight
                     NULL,                  -- Facility
                     @c_StorerKey,          -- Storer
                     NULL,                  -- No Sku in this Case
                     'OWITF',               -- ConfigKey
                @b_success             output,
                     @c_authority_OWITF     output,
                     @n_err                 output,
                     @c_errmsg              output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 62707
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                + ': Retrieve Failed On GetRight (OWITF). (ntrAdjustmentDetailAdd)'
            END
            ELSE IF @c_authority_OWITF = '1'
            BEGIN
               SELECT @c_authority_OWADJWO = STORERCONFIG.sValue
                 FROM ADJUSTMENT WITH (NOLOCK)
                 JOIN ADJUSTMENTDETAIL WITH (NOLOCK) ON ( ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey )
                 JOIN STORERCONFIG WITH (NOLOCK) ON ( ADJUSTMENTDETAIL.StorerKey = STORERCONFIG.StorerKey
                                                  AND STORERCONFIG.ConfigKey = 'OWADJWO' AND sValue = '1' )
                 JOIN CODELKUP WITH (NOLOCK) ON ( ADJUSTMENT.AdjustmentType = CODELKUP.Code
                                              AND CODELKUP.Listname = 'ADJTYPE' AND CODELKUP.Long = 'OWADJWO' )
                WHERE ADJUSTMENTDETAIL.AdjustmentKey = @c_ADJ_AdjustmentKey
                  AND ADJUSTMENTDETAIL.AdjustmentLineNumber = @c_ADJ_AdjustmentLineNumber
                  AND ADJUSTMENTDETAIL.FinalizedFlag = 'Y'

               IF @c_authority_OWADJWO = '1'
               BEGIN
                  EXEC ispGenTransmitLog 'OWADJWO', @c_ADJ_AdjustmentKey, @c_ADJ_AdjustmentLineNumber, @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62708
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                      + ': Insert Into TransmitLog Table (OWADJWO) Failed (ntrItrnAdd)'
                                      + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  END
               END -- IF @c_authority_OWADJWO = '1'
            END -- IF @c_authority_OWITF = '1'
            -- (YokeBeen01) - End
         END -- WHILE (1=1) -- AdjustmentLineNumber
      END -- WHILE (1=1) -- Adjustmentkey
   END

   /* #INCLUDE <TRADA2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
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
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrAdjustmentDetailAdd'
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