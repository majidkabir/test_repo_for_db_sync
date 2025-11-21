SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Trigger: ntrAdjustmentDetailUpdate                                          */
/* Creation Date:                                                              */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:                                                                    */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Called By: When records update into AdjustmentDetail                        */
/*                                                                             */
/* PVCS Version: 2.2                                                           */
/*                                                                             */
/* Version: 5.4                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/*                                                                             */
/* Updates:                                                                    */
/* Date         Author       Ver.   Purposes                                   */
/* 30-Aug-2004  Shong        1.0    Move from Branch                           */
/* 18-Oct-2004  Wally        1.0    Enable trafficcop / archivecop checking    */
/* 30-Jun-2005  Shong        1.0    Check Finalize option by Storer            */
/* 19-Oct-2006  MaryVong     1.0    Add in RDT compatible error messages       */
/* 28-Jun-2007  MaryVong     1.0    Remove dbo.fnc_RTRIM and dbo.fnc_LTRIM     */
/* 05-Jul-2007  Shong        1.0    SOS75806 - UCC Adjustment                  */
/* 04 Jan 2009  TLTING       1.0    Update eidtwho and editdate (tlting01)     */
/* 24-Mar-2010  YokeBeen     1.1    SOS#165421 - New Trigger point - "OWADJWO" */
/*                                  for WMS-E1 Work Order process.             */
/*                                  - (YokeBeen01)                             */
/* 31-Jan-2012  YTWan        1.3    Adjustment Status Control. (Wan01)         */
/* 28-Feb-2012  YTWan        1.4    Fixed. SOS#236991-NO Itrn & Not update     */
/*                                  inventory when finalized. (Wan02)          */
/* 07-May-2012  YTWan        1.5    SOS#242809-Continue to process if fail for */
/*                                  Storerconfig 'ADJStatusControl' turn on.   */
/*                                  (Wan03)                                    */
/* 23-May-2012  TLTING02     1.6    DM integrity - add update editdate B4      */
/*                                  TrafficCop for status < '9'                */     
/* 23-Jul-2013  KHLim        1.7    Insert ver. SOS162898 - Bond-Lock (KH01)   */
/* 05-Sep-2013  NJOW01       1.8    288779-fix to skip update UCC if adj create*/
/*                                  from CC UCC adj posting                    */
/* 18-Sep-2013  YTWan        1.82   Add Sku to UCC Checking (for Multisku).    */
/*                                  (Wan04)                                    */
/* 28-Oct-2013  TLTING       1.9    Review Editdate column update              */
/* 07-May-2014  TKLIM        1.10   Added Lottables 06-15                      */
/* 27-Jul-2017  TLTING       1.11   Remove SETROWCOUNT                         */
/* 09-Jan-2018  AikLiang     2.0    INC0093779 - Increase lottable06-12 size   */
/*                                  to 30, tally with itrn table (AL01)        */
/* 06-Feb-2018  SWT02        2.1    Added Channel Management Logic             */
/* 23-JUL-2019  Wan05        2.2    WMS-9872 - CN_NIKESDC_Exceed_Channel       */      
/* 10-May-2022  NJOW02       2.3    Add validation to ensure finalize correctly*/
/* 18-Aug-2023  NJOW03       2.4    WMS-23479 Support multi-sku ucc adjustment */
/* 18-Aug-2023  NJOW03       2.4    DEVOPS Combine Script                      */
/*******************************************************************************/

CREATE   TRIGGER [dbo].[ntrAdjustmentDetailUpdate]
ON  [dbo].[ADJUSTMENTDETAIL]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
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
         
         , @c_ChannelInventoryMgmt  NVARCHAR(10) = '0' -- (SWT02)         
         
         
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   /* #INCLUDE <TRADA1.SQL> */

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   -- tlting02
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
               WHERE  INSERTED.AdjustmentKey = DELETED.AdjustmentKey
               AND INSERTED.AdjustmentLineNumber = DELETED.AdjustmentLineNumber
               AND ( INSERTED.FinalizedFlag <> 'Y' OR DELETED.FinalizedFlag <> 'Y' ) ) 
         AND ( @n_continue = 1 or @n_continue = 2 )
         AND NOT UPDATE(EditDate)  
   BEGIN
      UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK) 
         SET TrafficCop = NULL, 
             EditDate = GETDATE(), 
             EditWho = SUSER_SNAME() 
        FROM ADJUSTMENTDETAIL 
        JOIN INSERTED ON ( ADJUSTMENTDETAIL.AdjustmentKey = inserted.AdjustmentKey 
                       AND ADJUSTMENTDETAIL.AdjustmentLineNumber = inserted.AdjustmentLineNumber )
      WHERE  ADJUSTMENTDETAIL.FinalizedFlag <> 'Y'
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62810 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                          + ': Update Failed On Table ADJUSTMENT. (ntrAdjustmentDetailUpdate) ( ' 
                          + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END


   -- tlting01
   IF ( @n_continue=1 OR @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
         SET TrafficCop = NULL,
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
        FROM ADJUSTMENTDETAIL
        JOIN INSERTED ON ( ADJUSTMENTDETAIL.AdjustmentKey = inserted.AdjustmentKey
                       AND ADJUSTMENTDETAIL.AdjustmentLineNumber = inserted.AdjustmentLineNumber )
      WHERE  INSERTED.FinalizedFlag = 'Y'       -- tlting02

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62800 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                          + ': Update Failed On Table ADJUSTMENT. (ntrAdjustmentDetailUpdate) ( '
                          + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE @c_FinalizeAdjustment NVARCHAR(1) -- Flag to see if overallocations are allowed.
      DECLARE @c_StorerKey NVARCHAR(15), 
              @c_Facility  NVARCHAR(10)

      DECLARE @c_Bondedflag Char(1)    --KH01
      
      SELECT TOP 1
             @c_StorerKey = INSERTED.StorerKey, 
             @c_Facility  = LOC.Facility 
      FROM   INSERTED 
      JOIN   LOC WITH (NOLOCK) ON LOC.LOC = INSERTED.LOC 

      SELECT @b_success = 0

      EXECUTE nspGetRight
               NULL,  -- Facility
               @c_StorerKey,      -- Storer
               NULL,              -- No Sku in this Case
               'FinalizeAdjustment', -- ConfigKey
               @b_success             output,
               @c_FinalizeAdjustment  output,
               @n_err                 output,
               @c_errmsg              output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62801 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                          + ': Retrieve Failed On GetRight. (ntrAdjustmentDetailUpdate)'
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
            SELECT @n_err = 62802  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Retrieve Failed On GetRight (AdjStatusControl). (ntrAdjustmentDetailUpdate)'
         END
      END 
      --(Wan01) - END

      IF @c_FinalizeAdjustment = '1' OR @c_ADJStatusCtrl = '1'
      BEGIN
         SELECT @n_continue = '1'
      END
      ELSE
      BEGIN
         SELECT @n_continue = 4
      END

      --(Wan05) - START
      -- (SWT02)
      --SET @c_ChannelInventoryMgmt = '0'
      --If @n_continue = 1 or @n_continue = 2
      --BEGIN
      --   SELECT @b_success = 0
      --   Execute nspGetRight     
      --   @c_Facility,
      --   @c_StorerKey,           -- Storer
      --   '',                     -- Sku
      --   'ChannelInventoryMgmt', -- ConfigKey
      --   @b_success    output,
      --   @c_ChannelInventoryMgmt  output,
      --   @n_err        output,
      --   @c_errmsg     output
      --   If @b_success <> 1
      --   BEGIN
      --      SELECT @n_continue = 3, @n_err = 61961, @c_errmsg = 'nspItrnAddAdjustmentCheck:' + ISNULL(RTRIM(@c_errmsg),'')
      --   END
      --END   
      --(Wan05) - END      
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF EXISTS( SELECT 1 FROM DELETED WHERE FinalizedFlag = 'Y' )
      BEGIN
         SELECT @n_continue = 3,
                @n_err = 62803,
                @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': UPDATE not allowed. (ntrAdjustmentDetailUpdate)'
      END
   END

   --NJOW02
   IF @n_continue IN(1,2) AND @c_ADJStatusCtrl = '1'
   BEGIN
   	  IF EXISTS (SELECT 1
   	             FROM INSERTED 
   	             JOIN DELETED ON INSERTED.AdjustmentKey = DELETED.AdjustmentKey   	                  
   	                          AND INSERTED.AdjustmentLineNumber = DELETED.AdjustmentLineNumber
   	             WHERE INSERTED.FinalizedFlag = 'Y'
   	             AND INSERTED.FinalizedFlag <> DELETED.FinalizedFlag
   	             AND DELETED.FinalizedFlag NOT IN ('N','A'))   	             
   	  BEGIN
         SELECT @n_continue = 3                                                                                        
         SELECT @n_err = 62757    	     
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Error. Previous Status is not N or A. (ntrAdjustmentDetailUpdate)'            	                	  
      END   
   END  

   IF @n_continue=1 or @n_continue=2      --KH01 start
   BEGIN
       SELECT @c_Bondedflag = '' 
       SELECT @b_Success = 0
      
       Execute nspGetRight null,         -- Facility
               @c_StorerKey, -- Storer
               null,         -- Sku
               'BondLocked',      -- ConfigKey
               @b_success    output, 
               @c_Bondedflag     output, 
               @n_err        output, 
               @c_errmsg     output
       If @b_success <> 1
       BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 62758 --60119 --62311   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve Failed On GetRight. (ntrAdjustmentDetailUpdate)'
       END
   END
   
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE  @c_ADJ_AdjustmentKey        NVARCHAR(10),
               @c_ADJ_AdjustmentLineNumber NVARCHAR(5),
               @c_ADJ_StorerKey            NVARCHAR(15),
               @c_ADJ_Sku                  NVARCHAR(20),
               @c_ADJ_Loc                  NVARCHAR(10),
               @c_ADJ_Lot                  NVARCHAR(10),
               @c_ADJ_Id                   NVARCHAR(18),
               @c_ADJ_ReasonCode           NVARCHAR(10),
               @n_ADJ_Qty                  int,
               @n_ADJ_CaseCnt              int,
               @n_ADJ_InnerPack            int,
               @n_ADJ_Pallet               int,
               @n_ADJ_Cube                 float,
               @n_ADJ_GrossWgt             float,
               @n_ADJ_NetWgt               float,
               @n_ADJ_OtherUnit1           float,
               @n_ADJ_OtherUnit2           float,
               @c_ADJ_packkey              NVARCHAR(10) ,
               @c_ADJ_uom                  NVARCHAR(10) ,
               @d_ADJ_EffectiveDate        datetime,
               @c_ItrnKey                  NVARCHAR(10),
               @c_SourceKey                NVARCHAR(15),
               @c_AdjustmentKey            NVARCHAR(10),
               @c_AdjustmentLineNumber     NVARCHAR(5),
               @c_ADJ_UCCNo                NVARCHAR(20) -- SOS75806
             , @c_Channel                  NVARCHAR(20) = '' --(SWT02)
             , @n_Channel_ID               BIGINT = 0 --(SWT02)

      DECLARE  @c_lottable01     NVARCHAR(18)   -- Lot lottable01
            ,  @c_lottable02     NVARCHAR(18)   -- Lot lottable02
            ,  @c_lottable03     NVARCHAR(18)   -- Lot lottable03
            ,  @d_lottable04     DATETIME       -- Lot lottable04
            ,  @d_lottable05     DATETIME       -- Lot lottable05
            ,  @c_Lottable06     NVARCHAR(30)   -- NVARCHAR(20)  AL01  
            ,  @c_Lottable07     NVARCHAR(30)   -- NVARCHAR(20)  AL01
            ,  @c_Lottable08     NVARCHAR(30)   -- NVARCHAR(20)  AL01
            ,  @c_Lottable09     NVARCHAR(30)   -- NVARCHAR(20)  AL01
            ,  @c_Lottable10     NVARCHAR(30)   -- NVARCHAR(20)  AL01
            ,  @c_Lottable11     NVARCHAR(30)   -- NVARCHAR(20)  AL01
            ,  @c_Lottable12     NVARCHAR(30)   -- NVARCHAR(20)  AL01
            ,  @d_Lottable13     DATETIME
            ,  @d_Lottable14     DATETIME
            ,  @d_Lottable15     DATETIME

             
      SELECT @c_ADJ_AdjustmentKey = SPACE(10)
      WHILE (1=1)
      BEGIN
         SELECT TOP 1 @c_ADJ_AdjustmentKey = INSERTED.AdjustmentKey
           FROM INSERTED
           JOIN DELETED ON ( INSERTED.AdjustmentKey = DELETED.AdjustmentKey )
          WHERE INSERTED.AdjustmentKey > @c_ADJ_AdjustmentKey
            AND INSERTED.FinalizedFlag = 'Y'
            --(Wan02) - START
            --AND DELETED.FinalizedFlag = 'N'
            AND   DELETED.FinalizedFlag IN ( 'N', 'A' )
            --(Wan02) - END
          ORDER BY INSERTED.AdjustmentKey

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         --(Wan05) - START
         SELECT TOP 1 @c_ChannelInventoryMgmt = SC.Authority
         FROM ADJUSTMENT ADJ WITH (NOLOCK)
         CROSS APPLY fnc_SelectGetRight (ADJ.facility, ADJ.StorerKey, '', 'ChannelInventoryMgmt') SC
         WHERE ADJ.AdjustmentKey = @c_ADJ_AdjustmentKey
         --(Wan05) - END

         --NJOW01
         SET @c_cckey = ''
         SELECT TOP 1 @c_cckey = StockTakeSheetParameters.StockTakeKey
         FROM ADJUSTMENT (NOLOCK)
         JOIN StockTakeSheetParameters (NOLOCK) ON ADJUSTMENT.CustomerRefNo = StockTakeSheetParameters.StockTakeKey 
         WHERE ADJUSTMENT.Adjustmentkey = @c_ADJ_AdjustmentKey          
             
         SELECT @c_ADJ_AdjustmentLineNumber = SPACE(5)
         WHILE (1=1)
         BEGIN
            SELECT TOP 1 @c_ADJ_AdjustmentKey       = INSERTED.AdjustmentKey,
                  @c_ADJ_AdjustmentLineNumber = INSERTED.AdjustmentLineNumber,
                  @c_ADJ_StorerKey            = INSERTED.StorerKey,
                  @c_ADJ_Sku                  = INSERTED.Sku,
                  @c_ADJ_Loc                  = INSERTED.Loc,
                  @c_ADJ_Lot                  = INSERTED.Lot,
                  @c_ADJ_Id                   = INSERTED.Id,
                  @c_ADJ_ReasonCode           = INSERTED.ReasonCode,
                  @n_ADJ_Qty                  = INSERTED.Qty,
                  @n_ADJ_CaseCnt              = INSERTED.CaseCnt,
                  @n_ADJ_InnerPack            = INSERTED.InnerPack,
                  @n_ADJ_Pallet               = INSERTED.Pallet,
                  @n_ADJ_Cube                 = INSERTED.Cube,
                  @n_ADJ_GrossWgt             = INSERTED.GrossWgt,
                  @n_ADJ_NetWgt               = INSERTED.NetWgt,
                  @n_ADJ_OtherUnit1           = INSERTED.OtherUnit1,
                  @n_ADJ_OtherUnit2           = INSERTED.OtherUnit2,
                  @c_ADJ_packkey              = INSERTED.Packkey ,
                  @c_ADJ_uom                  = INSERTED.UOM,
                  @d_ADJ_EffectiveDate        = INSERTED.EffectiveDate,
                  @c_ItrnKey                  = INSERTED.ItrnKey,
                  @c_ADJ_UCCNo                = ISNULL(INSERTED.UCCNo, '') -- SOS75806
                 , @c_Channel                  = INSERTED.Channel    --(SWT02)
                 , @n_Channel_ID               = INSERTED.Channel_ID --(SWT02)                  
            FROM INSERTED
            JOIN DELETED ON ( INSERTED.AdjustmentKey = DELETED.AdjustmentKey AND
                              INSERTED.AdjustmentLineNumber = DELETED.AdjustmentLineNumber )
            WHERE INSERTED.AdjustmentKey = @c_ADJ_AdjustmentKey
            AND   INSERTED.AdjustmentLineNumber > @c_ADJ_AdjustmentLineNumber
            AND   INSERTED.FinalizedFlag = 'Y'
            --(Wan02) - START
            --AND   DELETED.FinalizedFlag = 'N'
            AND   DELETED.FinalizedFlag IN ( 'N', 'A' )
            --(Wan02) - END
            ORDER BY INSERTED.AdjustmentKey, INSERTED.AdjustmentLineNumber

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
            -- Add by June 29.Jan.02
            -- HK Phase II : To Update Itrn's lottable details

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
            FROM  LOTATTRIBUTE WITH (NOLOCK)
            WHERE Lot = @c_ADJ_lot

            --KH01                
            IF @c_Bondedflag = '1' AND
               EXISTS ( SELECT 1 FROM Inventoryhold with (NOLOCK)
                           WHERE Hold = '1' 
                           AND Storerkey  = @c_ADJ_StorerKey
                           AND Sku        = @c_ADJ_Sku
                           AND Lottable02 = @c_lottable02 
                           AND LEN(RTRIM(Lottable02)) > 0 )
            BEGIN
                SELECT @n_err = 70000
                SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Bond-locked Stock. Adjustment Stock not allow. (ntrAdjustmentDetailUpdate)"
                Select @n_continue = 3
                BREAK  
            END   

            IF @c_ChannelInventoryMgmt = '1' 
            BEGIN 
               IF ISNULL(RTRIM(@c_Channel),'') = '' 
               BEGIN
                   SELECT @n_err = 70001
                   SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Channel Management Enabled, Channel Cannot be BLANK. (ntrAdjustmentDetailUpdate)"
                   Select @n_continue = 3
                   BREAK                                 
               END 
            END            

             /* (Wan03) - START */
            IF @c_ADJStatusCtrl = '1' 
            BEGIN
               IF @n_ADJ_Qty < 0 
               BEGIN
                  IF EXISTS  (SELECT 1 
                              FROM LOTXLOCXID WITH (NOLOCK) 
                              WHERE Lot = @c_ADJ_Lot
                              AND   Loc = @c_ADJ_Loc
                              AND   ID  = @c_ADJ_ID
                              AND   (Qty + @n_ADJ_Qty < 0
                              OR     Qty + @n_ADJ_Qty + QtyExpected < QtyAllocated + QtyPicked))
                  BEGIN
                     GOTO UPDATE_FAIL
                  END

                  IF EXISTS  (SELECT 1 
                              FROM LOT WITH (NOLOCK) 
                              WHERE Lot = @c_ADJ_Lot
                              AND   Qty + @n_ADJ_Qty < QtyPreAllocated + QtyAllocated + QtyPicked )
                  BEGIN
                     GOTO UPDATE_FAIL
                  END

                  GOTO QUIT_CHECK

                  UPDATE_FAIL:
                     UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
                     SET TrafficCop = NULL
                       , Finalizedflag = 'F'
                       , AddDate = GETDATE()
                       , AddWho  = SUSER_NAME()
                       , EditDate= GETDATE()
                       , EditWho = SUSER_NAME()
                     WHERE AdjustmentKey = @c_ADJ_AdjustmentKey
                     AND AdjustmentLineNumber = @c_ADJ_AdjustmentLineNumber

                     CONTINUE
                  QUIT_CHECK:
               END
            END
            /* (Wan03) - END */

            -- END - Add by June 29.Jan.02
            SELECT @c_SourceKey = dbo.fnc_LTRIM(dbo.fnc_RTRIM((@c_ADJ_AdjustmentKey)))
                                + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_ADJ_AdjustmentLineNumber))
            SELECT @b_success = 0

            EXECUTE  nspItrnAddAdjustment
                     @n_ItrnSysId  = NULL,
                     @c_StorerKey  = @c_ADJ_StorerKey,
                     @c_Sku        = @c_ADJ_Sku,
                     @c_Lot        = @c_ADJ_Lot,
                     @c_ToLoc      = @c_ADJ_Loc,
                     @c_ToID       = @c_ADJ_Id,
                     @c_Status     = '',
                     @c_lottable01 = @c_lottable01, -- Changed by June 29.Jan.02
                     @c_lottable02 = @c_lottable02, -- Changed by June 29.Jan.02
                     @c_lottable03 = @c_lottable03, -- Changed by June 29.Jan.02
                     @d_lottable04 = @d_lottable04, -- Changed by June 29.Jan.02
                     @d_lottable05 = @d_lottable05, -- Changed by June 29.Jan.02
                     @c_lottable06 = @c_lottable06,
                     @c_lottable07 = @c_lottable07,
                     @c_lottable08 = @c_lottable08,
                     @c_lottable09 = @c_lottable09,
                     @c_lottable10 = @c_lottable10,
                     @c_lottable11 = @c_lottable11,
                     @c_lottable12 = @c_lottable12,
                     @d_lottable13 = @d_lottable13,
                     @d_lottable14 = @d_lottable14,
                     @d_lottable15 = @d_lottable15,
                     @c_Channel    = @c_Channel, 
                     @n_Channel_ID = @n_Channel_ID OUTPUT,                     
                     @n_casecnt    = @n_ADJ_CaseCnt,
                     @n_innerpack  = @n_ADJ_InnerPack,
                     @n_qty        = @n_ADJ_Qty,
                     @n_pallet     = @n_ADJ_Pallet,
                     @f_cube       = @n_ADJ_Cube,
                     @f_grosswgt   = @n_ADJ_GrossWgt,
                     @f_netwgt     = @n_ADJ_NetWgt,
                     @f_otherunit1 = @n_ADJ_OtherUnit1,
                     @f_otherunit2 = @n_ADJ_OtherUnit2,
                     @c_SourceKey  = @c_SourceKey,
                     @c_SourceType = 'ntrAdjustmentDetailUpdate',
                     @c_PackKey    = @c_AdJ_packkey,
                     @c_UOM        = @c_ADJ_uom,
                     @b_UOMCalc    = 0,
                     @d_EffectiveDate = @d_ADJ_EffectiveDate,
                     @c_itrnkey    = @c_ItrnKey OUTPUT,
                     @b_Success    = @b_Success OUTPUT,
                     @n_err        = @n_err     OUTPUT,
                     @c_errmsg     = @c_errmsg  OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3 /* Other Error flags Set By nspItrnAddAdjustment */
               BREAK
            END
            ELSE
            BEGIN
            	 --NJOW02
            	 IF @c_ADJStatusCtrl = '1'
            	 BEGIN
            	 	  IF NOT EXISTS(SELECT 1 
            	 	                FROM ITRN (NOLOCK)
            	 	                WHERE TranType = 'AJ'
            	 	                AND SourceType = 'ntrAdjustmentDetailUpdate'
            	 	                AND SourceKey = @c_SourceKey
            	 	                AND Storerkey = @c_ADJ_StorerKey
            	 	                AND Sku = @c_ADJ_Sku)
            	 	  BEGIN
                     SELECT @n_continue = 3                                                                                        
                     SELECT @n_err = 62759    	     
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Error. Create ITRN failed. (ntrAdjustmentDetailUpdate)'        
                     BREAK    	                	              	 	  	
            	 	  END                          	 	                
            	 END
            	 
               -- SOS75806 UCC Adjustment
               IF @c_ADJ_UCCNo <> ''
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK)
                                  WHERE StorerKey = @c_ADJ_StorerKey AND UCCNo = @c_ADJ_UCCNo
                                   AND Sku = @c_ADJ_Sku) --NJOW03
                  BEGIN
                     INSERT INTO UCC (UCCNo, Storerkey, ExternKey, SKU, qty, Sourcekey,
                                      Sourcetype, Status, Lot, Loc, Id)

                     VALUES (@c_ADJ_UCCNo, @c_ADJ_StorerKey, '', @c_ADJ_Sku, @n_ADJ_Qty, @c_SourceKey,
                             'ADJUSTMENT', '1', @c_ADJ_Lot, @c_ADJ_Loc, @c_ADJ_ID)

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 62804 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                         + ': Insert Failed On Table UCC. (ntrAdjustmentDetailUpdate)'
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
                                        END,
                               EditDate = GETDATE(),           -- tlting
                               EditWho = SUSER_SNAME()
                        WHERE StorerKey = @c_ADJ_StorerKey  
                        AND   Sku   = @c_ADJ_Sku                     --(Wan04)
                        AND   UCCNo = @c_ADJ_UCCNo
                        AND   Status IN ('1','0')
                        
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 62805 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                            + ': Update Failed On Table UCC. (ntrAdjustmentDetailUpdate)'
                           BREAK
                        END
                     END
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
                      Channel_ID = @n_Channel_ID -- (SWT02)                      
                WHERE AdjustmentKey = @c_ADJ_AdjustmentKey
                  AND AdjustmentLineNumber = @c_ADJ_AdjustmentLineNumber

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62806 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                   + ': Update Failed On Table ADJUSTMENTDETAIL. (ntrAdjustmentDetailUpdate)'
                  BREAK
               END

               IF @n_cnt = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62807 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                   + ': No record updated into Table ADJUSTMENTDETAIL. (ntrAdjustmentDetailUpdate)'
                  BREAK
               END
            END

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
               SELECT @n_err = 62808
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                + ': Retrieve Failed On GetRight (OWITF). (ntrAdjustmentDetailUpdate)'
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
                     SELECT @n_err = 62809
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                      + ': Insert Into TransmitLog Table (OWADJWO) Failed (ntrItrnAdd)'
                                      + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  END
               END -- IF @c_authority_OWADJWO = '1'
            END -- IF @c_authority_OWITF = '1'
            -- (YokeBeen01) - END
         END -- WHILE (1=1) -- @c_ADJ_AdjustmentLineNumber
      END -- WHILE (1=1) -- @c_ADJ_AdjustmentKey
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

         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrAdjustmentDetailUpdate'
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