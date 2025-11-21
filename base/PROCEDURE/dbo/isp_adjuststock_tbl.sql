SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc : isp_AdjustStock_TBL                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Stock Take Posting by UCC# (specifically for TBL)           */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Nov-11  Shong         Performance Issues                        */
/* 2014-JUL-30  CSCHONG       Add Lottable06-15 (CS01)                  */
/* 07-Feb-2018  SWT02         Channel Management                        */
/************************************************************************/
CREATE PROC [dbo].[isp_AdjustStock_TBL] 
   @c_cckey NVARCHAR(10), 
   @b_success INT OUTPUT
AS
BEGIN
    -- main
    DECLARE @n_starttcnt          INT
           ,@c_ccdetailkey        NVARCHAR(10)
           ,@c_prev_storerkey     NVARCHAR(18)
           ,@c_prev_facility      NVARCHAR(5)
           ,@c_storerkey          NVARCHAR(18)
           ,@c_facility           NVARCHAR(5)
           ,@c_adjustmentkey      NVARCHAR(10)
           ,@n_err                INT
           ,@c_errmsg             NVARCHAR(250)
           ,@n_continue           INT
           ,@n_finalizestage      INT
           ,@c_status             NVARCHAR(10)
           ,@c_ucc                NVARCHAR(20)
           ,@c_sku                NVARCHAR(20)
           ,@n_systemqty          INT
           ,@c_lot                NVARCHAR(10)
           ,@c_loc                NVARCHAR(10)
           ,@c_id                 NVARCHAR(18)
           ,@n_cntqty             INT
           ,@c_Lottable01         NVARCHAR(18)
           ,@c_Lottable02         NVARCHAR(18)
           ,@c_Lottable03         NVARCHAR(18)
           ,@d_Lottable04         DATETIME
           ,@d_Lottable05         DATETIME
           ,@c_lottable06         NVARCHAR(30)  --CS01
           ,@c_lottable07         NVARCHAR(30)  --CS01
           ,@c_lottable08         NVARCHAR(30)  --CS01
           ,@c_lottable09         NVARCHAR(30)  --CS01
           ,@c_lottable10         NVARCHAR(30)  --CS01
           ,@c_lottable11         NVARCHAR(30)  --CS01
           ,@c_lottable12         NVARCHAR(30)  --CS01
           ,@d_lottable13         DATETIME   --CS01
           ,@d_lottable14         DATETIME   --CS01
           ,@d_lottable15         DATETIME   --CS01
           ,@d_today              DATETIME
           ,@c_sourcekey          NVARCHAR(20)
           ,@c_oldsku             NVARCHAR(20)
           ,@n_oldqty             INT
           ,@c_oldlot             NVARCHAR(10)
           ,@c_oldloc             NVARCHAR(10)
           ,@c_oldid              NVARCHAR(18)
           ,@c_oldstorer          NVARCHAR(18)  -- SOS29992
           ,@b_debug              INT
    
    SELECT @n_starttcnt = @@TRANCOUNT
    
    -- hardcoded values:
    DECLARE @c_type           NVARCHAR(2)
           ,@c_reasoncode     NVARCHAR(2)
           ,@c_remarks        NVARCHAR(30)
    
    IF LEFT(@c_cckey ,2)='ST' -- stock take
    BEGIN
        SET @c_type = 'AA'
        SET @c_reasoncode = 'AA'
    END
    ELSE
        -- normal cycle count
    BEGIN
        SET @c_type = 'PI'
        SET @c_reasoncode = 'PI'
    END
    
    SET @c_remarks = 'Stock Take Posting by UCC'
    
    SELECT @c_ccdetailkey = ''
    SELECT @c_prev_storerkey = ''
    SELECT @c_prev_facility = ''
    
    WHILE (1=1)
    BEGIN
        -- while
        SELECT @c_ccdetailkey = MIN(ccdetailkey)
        FROM   ccdetail(NOLOCK)
        WHERE  cckey = @c_cckey
               AND ccdetailkey>@c_ccdetailkey
               AND STATUS<'9'
        
        IF ISNULL(@c_ccdetailkey ,'0')='0'
            BREAK
        
        -- SOS29992
        BEGIN TRAN
        
        SELECT @c_storerkey = storerkey
              ,@c_facility         = facility
        FROM   ccdetail c(NOLOCK)
               JOIN loc l(NOLOCK)
                    ON  c.loc = l.loc
        WHERE  cckey               = @c_cckey
               AND ccdetailkey     = @c_ccdetailkey
        
        IF @c_prev_storerkey<>@c_storerkey
           OR @c_prev_facility<>@c_facility
        BEGIN
            -- new adjustment header record
            EXECUTE nspg_getkey
                    'Adjustment',
                 10,
                 @c_adjustmentkey OUTPUT,
                 @b_success OUTPUT,
                 @n_err OUTPUT,
                 @c_errmsg OUTPUT
            
            IF NOT @b_success=1
            BEGIN
                -- Start : SOS29992
                /*
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Obtain transmitlogkey. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                */
                ROLLBACK TRAN
                -- End : SOS29992
                BREAK
            END
            ELSE
                -- insert new adjustment header record
            BEGIN
                INSERT adjustment
                  (
                    adjustmentkey
                   ,adjustmenttype
                   ,storerkey
                   ,facility
                   ,customerrefno
                   ,remarks
                  )
                VALUES
                  (
                    @c_adjustmentkey
                   ,@c_type
                   ,@c_storerkey
                   ,@c_facility
                   ,@c_cckey
                   ,@c_remarks
                  )
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    -- SOS29992
                    /*
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Header. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                    */
                    ROLLBACK TRAN
                    BREAK
                END
            END
        END -- new adjustment header record
        
        -- insert adjustment details
        SELECT @n_finalizestage = finalizestage
        FROM   stocktakesheetparameters(NOLOCK)
        WHERE  stocktakekey = @c_cckey
        
        -- reverse back to previous select
        SELECT @c_status = STATUS
              ,@c_ucc              = refno
              ,@c_sku              = sku
              ,@n_systemqty        = systemqty
              ,@c_lot              = lot
              ,@c_loc              = loc
              ,@c_id               = id
              ,@n_cntqty           = CASE @n_finalizestage
                                WHEN 1 THEN qty
                                WHEN 2 THEN qty_cnt2
                                WHEN 3 THEN qty_cnt3
                           END
        FROM   CCDETAIL(NOLOCK)
        WHERE  CCKEY               = @c_cckey
               AND CCDETAILKEY     = @c_ccdetailkey
        --End of 
        -- status = '2' : inventory is existing
        IF @c_status='2'
           OR @c_status='0'
        BEGIN
            -- @c_status = '2'
            IF @n_cntqty<>@n_systemqty
            BEGIN
                -- @n_cntqty <> @n_systemqty
                IF EXISTS (
                       SELECT 1
                       FROM   ucc(NOLOCK)
                       WHERE  uccno = @c_ucc
                   )
                    UPDATE ucc
                    SET    qty       = @n_cntqty
                    WHERE  uccno     = @c_ucc
                ELSE
                    INSERT ucc
                      (
                        uccno
                       ,storerkey
                       ,sku
                       ,lot
                       ,loc
                       ,id
                       ,qty
                       ,STATUS
                       ,externkey
                      )
                    VALUES
                      (
                        @c_ucc
                       ,@c_storerkey
                       ,@c_sku
                       ,@c_lot
                       ,@c_loc
                       ,@c_id
                       ,@n_cntqty
                       ,'1'
                       ,''
                      )
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    ROLLBACK TRAN
                    BREAK
                END
                
                INSERT adjustmentdetail
                  (
                    adjustmentkey
                   ,adjustmentlinenumber
                   ,storerkey
                   ,sku
                   ,loc
                   ,lot
                   ,id
                   ,reasoncode
                   ,uom
                   ,packkey
                   ,qty
                  )
                SELECT @c_adjustmentkey
                      ,RIGHT(@c_ccdetailkey ,5)
                      ,@c_storerkey
                      ,@c_sku
                      ,@c_loc
                      ,@c_lot
                      ,@c_id
                      ,@c_reasoncode
                      ,p.packuom3
                      ,s.packkey
                      ,@n_cntqty-@n_systemqty
                FROM   sku s(NOLOCK)
                       JOIN pack p(NOLOCK)
                            ON  s.packkey = p.packkey
                WHERE  s.storerkey = @c_storerkey
                       AND s.sku = @c_sku
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    -- SOS29992
                    /*
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                    */
                    ROLLBACK TRAN
                    BREAK
                END
            END-- @n_cntqty <> @n_systemqty
        END -- @c_status = '2'
        
        -- status = '1' : new inventory
        IF @c_status='1'
           OR @c_status='4'
        BEGIN
            -- @c_status = '1'
            IF EXISTS (
                   SELECT 1
                   FROM   lotxlocxid(NOLOCK)
                   WHERE  storerkey     = @c_storerkey
                          AND sku       = @c_sku
                          AND lot       = @c_lot
                          AND loc       = @c_loc
                          AND id        = @c_id
               )
            BEGIN
                -- exists lotxlocxid
                
                INSERT adjustmentdetail
                  (
                    adjustmentkey
                   ,adjustmentlinenumber
                   ,storerkey
                   ,sku
                   ,loc
                   ,lot
                   ,id
                   ,reasoncode
                   ,uom
                   ,packkey
                   ,qty
                  )
                SELECT @c_adjustmentkey
                      ,RIGHT(@c_ccdetailkey ,5)
                      ,@c_storerkey
                      ,@c_sku
                      ,@c_loc
                      ,@c_lot
                      ,@c_id
                      ,@c_reasoncode
                      ,p.packuom3
                      ,s.packkey
                      ,@n_cntqty
                FROM   sku s(NOLOCK)
                       JOIN pack p(NOLOCK)
                            ON  s.packkey = p.packkey
                WHERE  s.storerkey = @c_storerkey
                       AND s.sku = @c_sku
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    -- SOS29992
                    /*
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                    */
                    ROLLBACK TRAN
                    BREAK
                END
            END-- exists lotxlocxid
            ELSE
                -- no inventory record
            BEGIN
                -- create inventory record and adjust
                /*CS01 start*/
                SELECT @c_lottable01 = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable01 ,'')
                                            WHEN 2 THEN ISNULL(lottable01_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable01_cnt3 ,'')
                                       END
                      ,@c_lottable02       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable02 ,'')
                                            WHEN 2 THEN ISNULL(lottable02_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable02_cnt3 ,'')
                                       END
                      ,@c_lottable03       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable03 ,'')
                                            WHEN 2 THEN ISNULL(lottable03_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable03_cnt3 ,'')
                                       END
                      ,@d_lottable04       = CASE @n_finalizestage
                                            WHEN 1 THEN lottable04
                                            WHEN 2 THEN lottable04_cnt2
                                            WHEN 3 THEN lottable04_cnt3
                                       END
                      ,@d_lottable05       = CASE @n_finalizestage
                                            WHEN 1 THEN lottable05
                                            WHEN 2 THEN lottable05_cnt2
                                            WHEN 3 THEN lottable05_cnt3
                                       END
                      ,@c_lottable06       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable06 ,'')
                                            WHEN 2 THEN ISNULL(lottable06_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable06_cnt3 ,'')
                                       END
                      ,@c_lottable07       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable07 ,'')
                                            WHEN 2 THEN ISNULL(lottable07_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable07_cnt3 ,'')
                                       END
                      ,@c_lottable08       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable08 ,'')
                                            WHEN 2 THEN ISNULL(lottable08_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable08_cnt3 ,'')
                                       END
                      ,@c_lottable09       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable09 ,'')
                                            WHEN 2 THEN ISNULL(lottable09_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable09_cnt3 ,'')
                                       END
                      ,@c_lottable10       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable10 ,'')
                                            WHEN 2 THEN ISNULL(lottable10_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable10_cnt3 ,'')
                                       END
                      ,@c_lottable11       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable11 ,'')
                                            WHEN 2 THEN ISNULL(lottable11_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable11_cnt3 ,'')
                                       END
                      ,@c_lottable12       = CASE @n_finalizestage
                                            WHEN 1 THEN ISNULL(lottable12 ,'')
                                            WHEN 2 THEN ISNULL(lottable12_cnt2 ,'')
                                            WHEN 3 THEN ISNULL(lottable12_cnt3 ,'')
                                       END
                      ,@d_lottable13       = CASE @n_finalizestage
                                            WHEN 1 THEN lottable13
                                            WHEN 2 THEN lottable13_cnt2
                                            WHEN 3 THEN lottable13_cnt3
                                       END
                      ,@d_lottable14       = CASE @n_finalizestage
                                            WHEN 1 THEN lottable14
                                            WHEN 2 THEN lottable14_cnt2
                                            WHEN 3 THEN lottable14_cnt3
                                       END
                      ,@d_lottable15       = CASE @n_finalizestage
                                            WHEN 1 THEN lottable15
                                            WHEN 2 THEN lottable15_cnt2
                                            WHEN 3 THEN lottable15_cnt3
                                       END
                      ,@d_today            = GETDATE()
                       /*CS01 End*/
                FROM   ccdetail(NOLOCK)
                WHERE  cckey               = @c_cckey
                       AND ccdetailkey     = @c_ccdetailkey
                
                -- insert a dummy deposit to create inventory record
                SELECT @c_sourcekey = @c_cckey+@c_ccdetailkey
                EXECUTE nspItrnAddDeposit
                     @n_ItrnSysId=NULL,
                     @c_StorerKey=@c_StorerKey,
                     @c_Sku=@c_SKU,
                     @c_Lot='',
                     @c_ToLoc=@c_LOC,
                     @c_ToID=@c_id,
                     @c_Status='OK',
                     @c_lottable01=@c_Lottable01,
                     @c_lottable02=@c_Lottable02,
                     @c_lottable03=@c_Lottable03,
                     @d_lottable04=@d_Lottable04,
                     @d_lottable05=@d_Lottable05,
                     @c_lottable06=@c_Lottable06,
                     @c_lottable07=@c_Lottable07,
                     @c_lottable08=@c_Lottable08,
                     @c_lottable09=@c_Lottable09,
                     @c_lottable10=@c_Lottable10,
                     @c_lottable11=@c_Lottable11,
                     @c_lottable12=@c_Lottable12,
                     @d_lottable13=@d_Lottable13,
                     @d_lottable14=@d_Lottable14,
                     @d_lottable15=@d_Lottable15,
                     @c_Channel='',
                     @n_Channel_ID=0,
                     @n_casecnt=0,  -- dummy qty
                     @n_innerpack=0,
                     @n_qty=0,
                     @n_pallet=0,
                     @f_cube=0,
                     @f_grosswgt=0,
                     @f_netwgt=0,
                     @f_otherunit1=0,
                     @f_otherunit2=0,
                     @c_SourceKey=@c_sourcekey,
                     @c_SourceType='DUMMY',
                     @c_PackKey='STD',
                     @c_UOM='EA',
                     @b_UOMCalc=0,
                     @d_EffectiveDate=@d_today,
                     @c_itrnkey="",
                     @b_Success=@b_Success OUTPUT,
                     @n_err=0,
                     @c_errmsg=''
                
                
                SELECT @n_err = @@error
                IF @b_success<>1
                BEGIN
                    IF @n_err>0
                    BEGIN
                        -- SOS29992
                        /*
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Dummy Deposit Failed. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                        */
                        ROLLBACK TRAN
                        BREAK
                    END
                END
                
                -- retrieve newly created lot
                SELECT @c_lot = SPACE(10)
                SELECT @c_lot = lot
                FROM   itrn(NOLOCK)
                WHERE  storerkey         = @c_storerkey
                       AND sku           = @c_sku
                       AND sourcekey     = @c_sourcekey
                
                
                INSERT adjustmentdetail
                  (
                    adjustmentkey
                   ,adjustmentlinenumber
                   ,storerkey
                   ,sku
                   ,loc
                   ,lot
                   ,id
                   ,reasoncode
                   ,uom
                   ,packkey
                   ,qty
                  )
                SELECT @c_adjustmentkey
                      ,RIGHT(@c_ccdetailkey ,5)
                      ,@c_storerkey
                      ,@c_sku
                      ,@c_loc
                      ,@c_lot
                      ,@c_id
                      ,@c_reasoncode
                      ,p.packuom3
                      ,s.packkey
                      ,@n_cntqty
                FROM   sku s(NOLOCK)
                       JOIN pack p(NOLOCK)
                            ON  s.packkey = p.packkey
                WHERE  s.storerkey = @c_storerkey
                       AND s.sku = @c_sku
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    -- SOS29992
                    /*
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                    */
                    ROLLBACK TRAN
                    BREAK
                END
            END -- create inventory record and adjust
            
            IF EXISTS (
                   SELECT 1
                   FROM   ucc(NOLOCK)
                   WHERE  uccno = @c_ucc
               )
               AND @c_ucc>''
            BEGIN
                -- duplicate ucc: negative adjust old ucc
                SELECT @c_oldloc = loc
                      ,@c_oldlot        = lot
                      ,@c_oldid         = id
                      ,@c_oldsku        = sku
                      ,@n_oldqty        = qty
                      ,@c_oldstorer     = storerkey -- SOS29992
                FROM   ucc(NOLOCK)
                WHERE  uccno            = @c_ucc
                
                
                -- Start : SOS29992
                IF EXISTS (
                       SELECT 1
                       FROM   lotxlocxid(NOLOCK)
                       WHERE  storerkey     = @c_oldstorer
                              AND sku       = @c_oldsku
                              AND lot       = @c_oldlot
                              AND loc       = @c_oldloc
                              AND id        = @c_oldid
                              AND qty>0
                   )
                BEGIN
                    -- End : SOS29992
                    INSERT adjustmentdetail
                      (
                        adjustmentkey
                       ,adjustmentlinenumber
                       ,storerkey
                       ,sku
                       ,loc
                       ,lot
                       ,id
                       ,reasoncode
                       ,uom
                       ,packkey
                       ,qty
                      )
                    SELECT @c_adjustmentkey
                          ,'D'+RIGHT(@c_ccdetailkey ,4)
                          ,@c_storerkey
                          ,@c_oldsku
                          ,@c_oldloc
                          ,@c_oldlot
                          ,@c_oldid
                          ,@c_reasoncode
                          ,p.packuom3
                          ,s.packkey
                          ,@n_oldqty*-1
                    FROM   sku s(NOLOCK)
                           JOIN pack p(NOLOCK)
                                ON  s.packkey = p.packkey
                    WHERE  s.storerkey = @c_storerkey
                           AND s.sku = @c_oldsku
                    
                    SELECT @n_err = @@error
                    IF @n_err>0
                    BEGIN
                        -- SOS29992
                        /*
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                        */
                        ROLLBACK TRAN
                        BREAK
                    END
                END -- SOS29992
                
                DELETE ucc
                WHERE  uccno = @c_ucc
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    -- SOS29992
                    /*
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Delete Duplicate UCC. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                    */
                    ROLLBACK TRAN
                    BREAK
                END
            END
            
            IF @c_ucc>''
                INSERT ucc
                  (
                    uccno
                   ,storerkey
                   ,sku
                   ,lot
                   ,loc
                   ,id
                   ,qty
                   ,STATUS
                   ,externkey
                  )
                VALUES
                  (
                    @c_ucc
                   ,@c_storerkey
                   ,@c_sku
                   ,@c_lot
                   ,@c_loc
                   ,@c_id
                   ,@n_cntqty
                   ,'1'
                   ,''
                  )
            
            SELECT @n_err = @@error
            IF @n_err>0
            BEGIN
                -- SOS29992
                /*
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert/Update Failed on UCC Table. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                */
                ROLLBACK TRAN
                BREAK
            END
        END -- @c_status = '1'
        
        -- Start : SOS29992
        -- Requested by Kim to set refno to blank if there's pending records
        -- Added by SHONG on 2005-Nov-10 
        IF @c_ucc>''
        BEGIN
            IF EXISTS (
                   SELECT 1
                   FROM   packheader ph(NOLOCK)
                         ,packdetail pd(NOLOCK)
                   WHERE  ph.pickslipno = pd.pickslipno
                          AND pd.refno = @c_ucc
                          AND ph.status<'9'
               )
            BEGIN
                UPDATE packdetail
                SET    refno = ''
                FROM   packheader ph(NOLOCK)
                WHERE  ph.pickslipno = packdetail.pickslipno
                       AND refno = @c_ucc
                       AND ph.status<'9'
                
                SELECT @n_err = @@error
                IF @n_err>0
                BEGIN
                    ROLLBACK TRAN
                    BREAK
                END
            END
        END -- if @c_ucc > '' 
        
        IF EXISTS (
               SELECT 1
               FROM   replenishment(NOLOCK)
               WHERE  refno = @c_ucc
                      AND confirmed<>'Y'
           )
        BEGIN
            UPDATE replenishment
            SET    refno = ''
            WHERE  refno = @c_ucc
                   AND confirmed<>'Y'
            
            SELECT @n_err = @@error
            IF @n_err>0
            BEGIN
                ROLLBACK TRAN
                BREAK
            END
        END 
        -- End : SOS29992
        
        -- finalize/close ccdetail record
        UPDATE ccdetail
        SET    STATUS = '9'
        WHERE  cckey = @c_cckey
               AND ccdetailkey = @c_ccdetailkey
        
        SELECT @n_err = @@error
        IF @n_err>0
        BEGIN
            -- SOS29992
            /*
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed on CCDETAIL Table. (isp_AdjustStock_TBL)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
            */
            ROLLBACK TRAN
            BREAK
        END
        ELSE
        BEGIN
            -- SOS29992
            COMMIT TRAN
        END
        
        SELECT @c_prev_storerkey = @c_storerkey
        SELECT @c_prev_facility = @c_facility
    END -- while
    
    /*
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
    execute nsp_logerror @n_err, @c_errmsg, 'isp_AdjustStock_TBL'
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
    RETURN
    END
    ELSE
    BEGIN
    SELECT @b_success = 1
    WHILE @@TRANCOUNT > @n_starttcnt
    BEGIN
    COMMIT TRAN
    END
    RETURN
    END
    */
END -- main

GO