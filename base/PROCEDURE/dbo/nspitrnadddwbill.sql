SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspItrnAddDWBill                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages      */
/* 22-Jun-2007  Shong         Bug Fixing                                */
/* 08-Oct-2007  James         Remove dbo.fnc_RTRIM and dbo.fnc_LTRIM    */
/************************************************************************/

CREATE PROC [dbo].[nspItrnAddDWBill]
@c_opcode       NVARCHAR(1)   -- 'D' - Deposit, 'W' = Withdrawal
,              @c_itrnkey      NVARCHAR(10)
,              @c_StorerKey    NVARCHAR(15)
,              @c_Sku          NVARCHAR(20)
,              @c_Lot          NVARCHAR(10)
,              @c_ToLoc        NVARCHAR(10)
,              @c_ToID         NVARCHAR(18)
,              @c_Status       NVARCHAR(10)
,              @n_casecnt      int       -- Casecount being inserted
,              @n_innerpack    int       -- innerpacks being inserted       
,              @n_Qty          int       -- QTY (Most important) being inserted
,              @n_pallet       int       -- pallet being inserted
,              @f_cube         float     -- cube being inserted
,              @f_grosswgt     float     -- grosswgt being inserted
,              @f_netwgt       float     -- netwgt being inserted
,              @f_otherunit1   float     -- other units being inserted.
,              @f_otherunit2   float     -- other units being inserted too.
,              @c_lottable01   NVARCHAR(18)
,              @c_lottable02   NVARCHAR(18)
,              @c_lottable03   NVARCHAR(18)
,              @d_lottable04   datetime
,              @d_lottable05   datetime
,              @c_sourcekey    NVARCHAR(20)
,              @c_sourcetype   NVARCHAR(30)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Added By Shong to Forces to uses Month/Day/Year Format
   SET DATEFORMAT mdy
   DECLARE   @n_continue int
   ,      @n_err2 int              -- For Additional Error Detection
   ,      @c_preprocess NVARCHAR(250)  -- preprocess
   ,      @c_pstprocess NVARCHAR(250)  -- post process
   ,      @n_cnt int                  /* variable to hold @@ROWCOUNT */
   
   SELECT @n_continue=1, @b_success=0, @n_err = 1, @c_errmsg=''
   SET ROWCOUNT 0 -- Make sure SQLServer is giving me all the rows I ask for.
   DECLARE   @c_temp_accumulatedchargeskey  NVARCHAR(10)
   ,      @c_temp_descrip            NVARCHAR(100)
   ,      @c_temp_storerkey          NVARCHAR(15)
   ,      @c_temp_sku                NVARCHAR(20)
   ,      @c_temp_lot                NVARCHAR(10)
   ,      @c_temp_id                 NVARCHAR(18)
   ,      @c_temp_UOMShow            NVARCHAR(10)
   ,      @c_temp_tariffkey          NVARCHAR(10)
   ,      @c_temp_tariffdetailkey    NVARCHAR(10)
   ,      @c_temp_taxgroupkey        NVARCHAR(10)
   ,      @n_temp_rate               decimal(22,6)
   ,      @c_temp_base               NVARCHAR(1)
   ,      @n_temp_masterunits        decimal(12,6)
   ,      @n_temp_sysgencharge       decimal(28,6)
   ,      @n_temp_debit              decimal(28,6)
   ,      @n_temp_billedunits        decimal(21,6)
   ,      @c_temp_chargetype         NVARCHAR(10)
   ,      @d_temp_billthrudate       datetime
   ,      @d_temp_billfromdate       datetime
   ,      @c_temp_sourcekey          NVARCHAR(20)
   ,      @c_temp_sourcetype         NVARCHAR(30)
   ,      @c_temp_gldistributionkey  NVARCHAR(10)
   ,      @n_pallet_billed           int
   ,      @c_temp_roundmasterunits   NVARCHAR(10)
   ,      @d_temp_costrate           decimal(22,6)
   ,      @c_temp_costbase           NVARCHAR(1)
   ,      @d_temp_costmasterunits    decimal(12,6)
   ,      @c_temp_costuomshow        NVARCHAR(10)
   ,      @d_temp_sysgencost         decimal(28,6)
   ,      @d_temp_cost               decimal(28,6)
   ,      @d_temp_costunits          decimal(21,6)
   SELECT @c_temp_storerkey = @c_StorerKey
   SELECT @c_temp_sku = @c_Sku
   SELECT @c_temp_lot = @c_Lot
   SELECT @c_temp_id = @c_toid
   SELECT @n_temp_billedunits = @n_Qty
   SELECT @c_temp_sourcekey = @c_itrnkey -- Point to the ITRN record
   SELECT @c_temp_sourcetype = 'ITRN' -- Identify SourceKey as an ITRN Key
   /* #INCLUDE <SPIADWB1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE   @d_effectivedate datetime
      SELECT @d_effectivedate = EffectiveDate
      FROM ITRN (nolock)
      WHERE ItrnKey = @c_itrnkey
      SELECT @n_Qty = ABS(@n_Qty)
      DECLARE @n_StdGrossWgt float, @n_StdCube float, @c_document_tariffkey NVARCHAR(10)
      IF @c_opcode = 'D'
      BEGIN
         IF ( @c_sourcetype = 'ntrReceiptDetailUpdate' or
         @c_sourcetype = 'ntrReceiptDetailAdd')
         and
         ( dbo.fnc_RTrim(@c_sourcekey) IS NOT NULL)
         BEGIN
            SELECT @c_document_tariffkey = TariffKey
            FROM RECEIPTDETAIL (nolock)
            WHERE ReceiptKey = SUBSTRING(@c_sourcekey,1,10)
            AND ReceiptLineNumber = SUBSTRING(@c_sourcekey,11,5)
            AND StorerKey = @c_StorerKey
            AND Sku = @c_sku
         END
      END
      IF @c_opcode = 'W'
      BEGIN
         IF  ( @c_sourcetype = 'ntrPickDetailUpdate' )
         and ( dbo.fnc_RTrim(@c_sourcekey) IS NOT NULL)
         BEGIN
            SELECT @c_document_tariffkey = OD.TariffKey
            FROM ORDERDETAIL OD (nolock), PICKDETAIL PD (nolock)
            WHERE PD.PickDetailKey = SUBSTRING(@c_sourcekey,1,10)
            AND OD.OrderKey = PD.OrderKey
            AND OD.OrderLineNumber = PD.OrderLineNumber
            AND OD.StorerKey = @c_StorerKey
            AND OD.Sku = @c_sku
            AND PD.StorerKey = @c_StorerKey
            AND PD.Sku = @c_sku
         END
      END
      SELECT @c_temp_tariffkey = TariffKey,
             @n_StdGrossWgt = StdGrossWgt,
             @n_StdCube = StdCube
      FROM SKU (nolock)
      WHERE SKU.StorerKey = @c_StorerKey
      AND SKU.Sku = @c_Sku
      
      /***** START 18th April 2001 Customization for IDS ********/
      DECLARE @c_Facility NVARCHAR(5)
      IF NOT (@c_sourcetype = 'ntrReceiptDetailUpdate' OR @c_sourcetype = 'ntrReceiptDetailAdd')
      BEGIN
         SELECT @c_Facility = Facility
         FROM LOC (nolock)
         WHERE LOC.Loc = @c_ToLoc
      END
      
      IF ISNULL(dbo.fnc_RTrim(@c_Facility), '') <> '' AND IsNull(dbo.fnc_RTrim(@c_temp_tariffkey), '') = ''
      BEGIN
         SELECT @c_temp_tariffkey = TariffKey
         FROM  TARIFFXFACILITY (nolock)
         WHERE TARIFFXFACILITY.Facility = @c_Facility
           AND TARIFFXFACILITY.StorerKey = @c_StorerKey
           AND TARIFFXFACILITY.Sku = @c_Sku
      END
      /***** END 18th April 2001 Customization for IDS ********/
      -- Comment by SHONG on 22th Jun 2007 
      -- If Facility Level not set, shouldn't raise error 
      /*
      IF IsNull(dbo.fnc_dbo.fnc_RTrim(dbo.fnc_dbo.fnc_LTrim(@c_temp_tariffkey)), '') = ''
      BEGIN
         SELECT @n_continue = 3 , @n_err = 62401 --75000
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': There is no TariffKey. (nspItrnAddDWBill)'
      END
      */ 
      
      IF IsNull(dbo.fnc_RTrim(@c_document_tariffkey), '') = '' AND IsNull(dbo.fnc_RTrim(@c_temp_tariffkey), '') <> '' 
      BEGIN
         SELECT @c_document_tariffkey = @c_temp_tariffkey
      END
      
      IF (@n_continue = 1 or @n_continue = 2)-- DS: AND NOT (dbo.fnc_dbo.fnc_RTrim(@c_temp_tariffkey) = 'XXXXXXXXXX')
      BEGIN
         DECLARE @c_periodtype                 NVARCHAR(1),
                 @n_initialstorageperiod       int,
                 @n_splitmonthday              int,
                 @n_splitmonthpercent          decimal(12,6),
                 @n_splitmonthpercentbefore    decimal(12,6),
                 @c_calendargroup              NVARCHAR(10),
                 @c_calendarinvalid            NVARCHAR(1),
                 @c_captureendofmonth          NVARCHAR(1)
                 
         SELECT @c_periodtype              = dbo.fnc_RTrim(PeriodType),
                @n_initialstorageperiod    = InitialStoragePeriod,
                @n_splitmonthday           = SplitMonthDay,
                @n_splitmonthpercent       = SplitMonthPercent,
                @n_splitmonthpercentbefore = SplitMonthPercentBefore,
                @c_calendargroup           = dbo.fnc_RTrim(CalendarGroup),
                @c_captureendofmonth       = CaptureEndOfMonth
         FROM Tariff (nolock)
         WHERE TariffKey = @c_document_tariffkey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0 or @n_cnt <> 1
         BEGIN
            SELECT @n_continue = 3 , @n_err = 62402 --75000
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid TariffKey. (nspItrnAddDWBill)'
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            DECLARE @c_bill_HI            NVARCHAR(10), 
                    @c_bill_HO            NVARCHAR(10), 
                    @c_transferlinenumber NVARCHAR(5),
                    @c_relot              NVARCHAR(10), 
                    @c_fromstorerkey      NVARCHAR(15), 
                    @c_fromsku            NVARCHAR(20),
                    @c_tostorerkey        NVARCHAR(15), 
                    @c_tosku              NVARCHAR(20), 
                    @c_fromlot            NVARCHAR(10)
            DECLARE @c_xfrdoc             NVARCHAR(10)
            IF  ( @c_sourcetype = 'ntrTransferDetailUpdate' or @c_sourcetype = 'ntrTransferDetailAdd')
            AND ( ISNULL(dbo.fnc_RTrim(@c_sourcekey), '') <> '')
            BEGIN
               SELECT @c_xfrdoc = SUBSTRING(@c_sourcekey,1,10),
                      @c_transferlinenumber = SUBSTRING(@c_sourcekey,11,15)
                      
               SELECT @c_bill_HI = GenerateIS_HICharges,
                      @c_bill_HO = GenerateHOCharges,
                      @c_relot = Relot,
                      @c_fromstorerkey = TRANSFERDETAIL.FromStorerKey,
                      @c_tostorerkey = TRANSFERDETAIL.ToStorerKey,
                      @c_fromsku = TRANSFERDETAIL.FromSku,
                      @c_tosku = TRANSFERDETAIL.ToSku,
                      @c_fromlot = TRANSFERDETAIL.FromLot
               FROM TRANSFER (nolock), TRANSFERDETAIL (nolock)
               WHERE TRANSFERDETAIL.TransferKey = @c_xfrdoc
               and TRANSFERDETAIL.TransferLineNumber = @c_transferlinenumber
               and TRANSFERDETAIL.TransferKey = TRANSFER.TransferKey
               IF NOT (@c_opcode = 'D'
                  and @c_fromstorerkey = @c_tostorerkey
                  and @c_fromsku = @c_tosku
                  and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromlot)) is not Null
                  and @c_relot = '1')
               BEGIN
                  SELECT @c_relot = '0'
               END
            END -- ntrTransferDetailUpdate
         END
         DECLARE @d_date datetime, @n_day int, @n_month int, @n_year int
         SELECT @d_date  = @d_effectivedate
         SELECT @n_day   = DATEPART(dd, @d_date)
         SELECT @n_month = DATEPART(mm, @d_date)
         SELECT @n_year  = DATEPART(yy, @d_date)
         SELECT @d_temp_billfromdate = convert(datetime, convert(char(10), @d_date, 101) )
         SELECT @d_temp_billthrudate = @d_temp_billfromdate
         DECLARE @dt_calendar_splitdate datetime, @dt_calendar_periodend datetime
         IF @c_periodtype = 'C'
         BEGIN
            SET ROWCOUNT 1
            
            SELECT @dt_calendar_splitdate = SplitDate,
                   @dt_calendar_periodend = PeriodEnd
            FROM CALENDARDETAIL (NOLOCK) 
            WHERE CalendarGroup = @c_calendargroup
            and convert(datetime, convert(char(10), PeriodEnd, 101) + ' 23:59') > @d_date
            ORDER BY PeriodEnd
            
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 --OR @n_cnt <> 1 OR @dt_calendar_periodend IS NULL
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err= 62403 --75001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to get dates for Calendar Group ' + @c_calendargroup + ' (nspItrnAddDWBill)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            ELSE IF @n_cnt <> 1 OR @dt_calendar_periodend IS NULL
            BEGIN
               SELECT @c_calendarinvalid = '1'
            END
            SET ROWCOUNT 0
         END
         IF @c_opcode = 'D'
         BEGIN
            DECLARE @d_lotbillthrudate datetime
            
            SELECT @d_lotbillthrudate = LotBillThruDate
              FROM LotxBilldate WITH (NOLOCK) 
            WHERE Lot = @c_temp_lot
            
            IF @d_lotbillthrudate IS NULL
            BEGIN
               DECLARE  @d_lastactivity      datetime
               ,   @n_qtybilledbalance  int
               ,   @n_qtybilledgweight  float
               ,   @n_qtybillednweight  float
               ,   @n_qtybilledcube     float
               SELECT   @d_lastactivity = @d_effectivedate
               SELECT   @n_qtybilledbalance = 0
               SELECT   @n_qtybilledgweight = 0.0
               SELECT   @n_qtybillednweight = 0.0
               SELECT   @n_qtybilledcube = 0.0
               SELECT @d_lotbillthrudate = ( CASE
               WHEN @c_periodtype = 'S' -- Split Month: BillThruDate = End of Current Month
               THEN dateadd(mi, -1, dateadd(mm, 1, convert(datetime, convert(char(2), @n_month) + '/01/' + convert(char(4), @n_year), 101)))
               WHEN @c_periodtype = 'A' and @c_captureendofmonth = '0' -- Anniversary
               THEN dateadd(mm, 1, dateadd(mi, -1, convert(datetime,convert(char(10),@d_date,101))))
               WHEN @c_periodtype = 'A' and @c_captureendofmonth = '1' -- Anniversary
               THEN dateadd(mi, -1, dateadd(dd, -1, dateadd(mm, 1, dateadd(dd,1,convert(datetime,convert(char(10),@d_date,101))))))
               WHEN @c_periodtype = 'F' -- Fixed Period
               THEN dateadd(mi, -1, dateadd(dd, @n_initialstorageperiod, convert(datetime,convert(char(10),@d_date,101))))
               WHEN @c_periodtype = 'C' and @c_calendarinvalid <> '1'-- Special Calendar is OK
               THEN dateadd(mi, -1, dateadd(dd, 1, convert(datetime,convert(char(10),@dt_calendar_periodend,101))))
               WHEN @c_periodtype = 'C' and @c_calendarinvalid = '1'-- Special Calendar is invalid. Use End of Month
               THEN dateadd(mi, -1, dateadd(mm, 1, convert(datetime, convert(char(2), @n_month) + '/01/' + convert(char(4), @n_year), 101)))
               ELSE
               dateadd(mi, -1, convert(datetime,convert(char(10),@d_date,101)))
               END )-- end case @c_periodtype
               IF @c_relot = '1'
               BEGIN
                  SELECT @d_lotbillthrudate = LotBillThruDate
                  FROM LotxBilldate (nolock)
                  WHERE Lot = @c_FromLot
               END            
               DECLARE @n_anniversarystartdate datetime
               SELECT @n_anniversarystartdate = ( CASE @c_periodtype
                  WHEN 'A' THEN convert(datetime,convert(char(10),@d_date,101))
                  ELSE DateAdd(mi,1,@d_lotbillthrudate) END )
                  
               DECLARE @c_tariff_to_insert NVARCHAR(10)
               SELECT @c_tariff_to_insert = @c_temp_tariffkey
               IF EXISTS (SELECT 1 FROM NSQLCONFIG (nolock)
               WHERE ConfigKey = 'RSTARIFFOVERRIDE' and NSQLValue = '1')
               BEGIN
                  SELECT @c_tariff_to_insert = @c_document_tariffkey
               END        
               INSERT LotxBilldate (Lot,
                  Tariffkey,
                  LotBillThruDate,
                  LastActivity,
                  AnniversaryStartDate,
                  QtyBilledBalance,
                  QtyBilledGrossWeight,
                  QtyBilledNetWeight,
                  QtyBilledCube)
               VALUES (@c_temp_lot,
                  @c_tariff_to_insert,
                  @d_lotbillthrudate,
                  @d_lastactivity,
                  @n_anniversarystartdate,
                  @n_qtybilledbalance,
                  @n_qtybilledgweight,
                  @n_qtybillednweight,
                  @n_qtybilledcube )
               SELECT @n_err = @@ERROR
               IF @n_err <> 0 -- Some fatal error occurred
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err= 62404 --75001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into LotxBillDate failed (nspItrnAddDWBill)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- @d_lotbillthrudate IS NULL
         END -- @c_opcode is 'D'
      END -- @n_continue = 1 or @n_continue = 2
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF ( @c_sourcetype = 'ntrTransferDetailUpdate' or
              @c_sourcetype = 'ntrTransferDetailAdd')
         and
         ( dbo.fnc_RTrim(@c_sourcekey) IS NOT NULL)
         BEGIN
            IF (@c_opcode = 'D'  and @c_bill_HI <> '1')
            OR (@c_opcode = 'W'  and @c_bill_HO <> '1')
            BEGIN
               SELECT @n_continue = 4
            END
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @c_temp_tariffkey = @c_document_tariffkey
         DECLARE @b_cursor_opened int -- Boolean flag: Was the cursor opened successfully?
         
         DECLARE_CURSOR: -- Label used to jump to when trying to declare and open cursor.
         
         SELECT @b_cursor_opened = 0 -- Initialize to FALSE
         IF @c_opcode = 'D'
         BEGIN
            DECLARE cTariffDetailLines CURSOR LOCAL FAST_FORWARD READ_ONLY
            FOR SELECT TariffDetailKey,ChargeType, Descrip, Rate, Base, MasterUnits,
                  UOMShow, TaxGroupKey, GLDistributionKey, RoundMasterUnits,
                  UOM1Mult, UOM2Mult, UOM3Mult, UOM4Mult,
                  CostRate, CostBase, CostMasterUnits, CostUOMShow
            FROM TariffDetail WITH (NOLOCK) 
            WHERE TariffKey = @c_temp_tariffkey
            AND (dbo.fnc_RTrim(ChargeType) = 'IS' OR dbo.fnc_RTrim(ChargeType) = 'HI')
         END
         ELSE
         IF @c_opcode = 'W'
         BEGIN
            DECLARE cTariffDetailLines CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT  TariffDetailKey,ChargeType, Descrip, Rate, Base, MasterUnits,
                     UOMShow, TaxGroupKey, GLDistributionKey, RoundMasterUnits,
                     UOM1Mult, UOM2Mult, UOM3Mult, UOM4Mult,
                     CostRate, CostBase, CostMasterUnits, CostUOMShow
            FROM TariffDetail WITH (NOLOCK) 
            WHERE TariffKey = @c_temp_tariffkey
            AND dbo.fnc_RTrim(ChargeType) = 'HO'
         END
         SELECT @n_err = @@ERROR
         IF @n_err = 16915 /* Cursor Already Exists So Close, Deallocate And Try Again! */
         BEGIN
            CLOSE cTariffDetailLines
            DEALLOCATE cTariffDetailLines
            GOTO DECLARE_CURSOR
         END
         IF @n_err <> 0 -- Some other fatal error occurred
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err= 62405 --75002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Declaration of cursor failed (nspItrnAddDWBill)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            OPEN cTariffDetailLines /* Open the CURSOR for access. */
            SELECT @n_err = @@ERROR
            IF @n_err = 16905 /* Cursor Already Opened! */
            BEGIN
               CLOSE cTariffDetailLines
               DEALLOCATE cTariffDetailLines
               GOTO DECLARE_CURSOR
            END
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err= 62406 --75003  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': open of cursor failed (nspItrnAddDWBill)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END /* end IF @n_continue = 1 or @n_continue = 2 */
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @b_cursor_opened = 1
            DECLARE @d_uom1mult decimal(12,6), @d_uom2mult decimal(12,6), 
                    @d_uom3mult decimal(12,6), @d_uom4mult decimal(12,6),
                    @d_uom5mult decimal(12,6), @d_multiplier decimal(12,6), 
                    @c_mult_descrip NVARCHAR(100)
                    
            FETCH NEXT FROM cTariffDetailLines
            INTO @c_temp_tariffdetailkey, @c_temp_chargetype, @c_temp_descrip, @n_temp_rate, @c_temp_base,
                 @n_temp_masterunits, @c_temp_UOMShow, @c_temp_taxgroupkey, @c_temp_gldistributionkey,
                 @c_temp_roundmasterunits, @d_uom1mult, @d_uom2mult, @d_uom3mult, @d_uom4mult,
                 @d_temp_costrate, @c_temp_costbase, @d_temp_costmasterunits, @c_temp_costuomshow
                 
            SELECT @n_cnt = @@ROWCOUNT
            WHILE (@n_cnt = 1 AND (@n_continue = 1 or @n_continue = 2)) /* A row has been returned, generate a AccumulatedCharges row for it. */
            BEGIN
               SELECT @c_temp_chargetype = dbo.fnc_RTrim(@c_temp_chargetype)
               SELECT @c_temp_descrip = dbo.fnc_RTrim(@c_temp_descrip)
               SELECT @c_temp_base = dbo.fnc_RTrim(@c_temp_base)
               IF (@c_temp_base = 'Q') -- Quantity
               BEGIN
                  SELECT @n_temp_billedunits = (@n_qty / @n_temp_masterunits)
               END
               IF (@c_temp_base = 'G') -- Gross Weight
               BEGIN
                  SELECT @n_temp_billedunits = (@n_qty / @n_temp_masterunits) * Convert(dec(21,6),@n_StdGrossWgt)
               END
               IF (@c_temp_base = 'C') -- Cube
               BEGIN
                  SELECT @n_temp_billedunits = (@n_qty / @n_temp_masterunits) * Convert(dec(21,6),@n_StdCube)
               END
               IF (@c_temp_base = 'F') -- Flat charge
               BEGIN
                  SELECT @n_temp_billedunits = 1.0
               END
               IF (@c_temp_base = 'R') -- Revenue Ton
               BEGIN
                  IF @n_StdGrossWgt > @n_StdCube
                  BEGIN
                     SELECT @n_temp_billedunits = (@n_qty / @n_temp_masterunits) * Convert(dec(21,6),@n_StdGrossWgt)
                     SELECT @c_temp_descrip = ISNULL(dbo.fnc_RTrim(@c_temp_descrip), '') + ' by Gross Weight'
                  END
                  ELSE IF @n_StdCube > 0.0
                  BEGIN
                     SELECT @n_temp_billedunits = (@n_qty / @n_temp_masterunits) * Convert(dec(21,6),@n_StdCube)
                     SELECT @c_temp_descrip = ISNULL(dbo.fnc_RTrim(@c_temp_descrip), '') + ' by Cube'
                  END
                  ELSE SELECT @n_temp_billedunits = 0.0
               END
               IF (@c_temp_base = 'P') -- Pallet
               BEGIN
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NULL
                  BEGIN
                     GOTO GETNEXTROW  -- No charges to be generated for blank ids when billing by pallets.
                  END
                  SELECT @n_pallet_billed = COUNT(1) FROM AccumulatedCharges (nolock)
                  WHERE AccumulatedCharges.Chargetype=@c_temp_chargetype
                  AND AccumulatedCharges.Status = '0'
                  AND AccumulatedCharges.Tariffdetailkey = @c_temp_tariffdetailkey
                  AND AccumulatedCharges.Id = @c_toid
                  IF @n_pallet_billed = 0 or @n_pallet_billed IS NULL
                  BEGIN
                     SELECT @n_temp_billedunits = 1.0, @n_pallet_billed = 1
                  END
                  ELSE
                  BEGIN
                     GOTO GETNEXTROW
                  END
               END
               IF @c_temp_roundmasterunits = '1'
               BEGIN
                  SELECT @c_temp_descrip = ISNULL(dbo.fnc_RTrim(@c_temp_descrip), '') + ' - Rounded Upwards From ' + CONVERT(CHAR(20),@n_temp_billedunits)
                  SELECT @n_temp_billedunits = CEILING(@n_temp_billedunits)
               END
               IF @c_temp_chargetype = 'IS'  -- Initial Storage
               BEGIN
                  IF @c_periodtype = 'S'  -- Split Month
                BEGIN
                     IF DATEPART(dd, @d_effectivedate) < @n_splitmonthday
                     BEGIN
                        SELECT @n_temp_debit = (@n_temp_rate * @n_temp_billedunits) * @n_splitmonthpercentbefore
                     END
                     ELSE
                     BEGIN
                        SELECT @n_temp_debit = (@n_temp_rate * @n_temp_billedunits) * @n_splitmonthpercent
                     END
                  END
                  ELSE IF @c_periodtype = 'C' AND @c_calendarinvalid <> '1' -- Special Calendar
                  BEGIN
                     IF DATEDIFF(dd, @d_effectivedate, @dt_calendar_splitdate) > 0
                     BEGIN
                        SELECT @n_temp_debit = (@n_temp_rate * @n_temp_billedunits) * @n_splitmonthpercentbefore
                     END
                     ELSE
                     BEGIN
                        SELECT @n_temp_debit = (@n_temp_rate * @n_temp_billedunits) * @n_splitmonthpercent
                     END
                  END
                  ELSE IF @c_periodtype = 'C' AND @c_calendarinvalid = '1'  -- Reset to Split Month
                  BEGIN
                     IF DATEPART(dd, @d_effectivedate) < @n_splitmonthday
                     BEGIN
                        SELECT @n_temp_debit = (@n_temp_rate * @n_temp_billedunits) * @n_splitmonthpercentbefore
                     END
                     ELSE
                     BEGIN
                        SELECT @n_temp_debit = (@n_temp_rate * @n_temp_billedunits) * @n_splitmonthpercent
                     END
                     SELECT @c_temp_descrip = ISNULL(dbo.fnc_RTrim(@c_temp_descrip), '') + ' by Split Month Period Type'
                  END
                  ELSE IF @c_periodtype = 'A'  -- Anniversary
                  BEGIN
                     SELECT @n_temp_debit = @n_temp_rate * @n_temp_billedunits
                  END
                  ELSE IF @c_periodtype = 'F'  -- Fixed
                  BEGIN
                     SELECT @n_temp_debit = @n_temp_rate * @n_temp_billedunits
                  END
               END /* IF @c_temp_chargetype = 'IS' */
               IF @c_temp_chargetype IN ('HI', 'HO')
               BEGIN
                  SELECT @d_multiplier = CASE
                  WHEN @n_casecnt    <> 0 THEN @d_uom1mult
                  WHEN @n_innerpack  <> 0 THEN @d_uom2mult
                  WHEN @n_pallet     <> 0 THEN @d_uom4mult
                  WHEN @f_cube       <> 0 THEN 1.0
                  WHEN @f_grosswgt   <> 0 THEN 1.0
                  WHEN @f_netwgt     <> 0 THEN 1.0
                  WHEN @f_otherunit1 <> 0 THEN 1.0
                  WHEN @f_otherunit2 <> 0 THEN 1.0
               ELSE @d_uom3mult END
               SELECT @c_mult_descrip = ''
               IF @d_multiplier <> 1.0
               BEGIN
                  SELECT @c_mult_descrip = CASE
                  WHEN @n_pallet <> 0
                  THEN ' by Pallet Multiplier'
                  WHEN @n_casecnt <> 0
                  THEN ' by Case Multiplier'
                  WHEN @n_innerpack <> 0
                  THEN ' by InnerPack Multiplier'
                  WHEN @f_cube <> 0
                  THEN ' by Cube Multiplier'
               ELSE ' by Each Multiplier' END
               END
               SELECT @c_temp_descrip = ISNULL(dbo.fnc_RTrim(@c_temp_descrip), '') + dbo.fnc_RTrim(@c_mult_descrip)
               SELECT @n_temp_debit = @n_temp_rate* @d_multiplier * @n_temp_billedunits
               END /* IF @c_temp_chargetype IN ('HI', 'HO') */
               IF @c_temp_chargetype in ( 'HI', 'HO')
               BEGIN
                  SELECT @d_temp_billthrudate = @d_temp_billfromdate
               END
               ELSE
               BEGIN
                  SELECT @d_temp_billthrudate = @d_lotbillthrudate
               END
               SELECT @d_temp_costunits = ( CASE
               WHEN @c_temp_costbase = 'F'
               THEN 1.0
               WHEN @c_temp_costbase = 'Q'
               THEN (@n_qty / @d_temp_costmasterunits)
               WHEN @c_temp_costbase = 'C'
               THEN (@n_qty / @d_temp_costmasterunits) * Convert(dec(21,6),@n_StdCube)
               WHEN @c_temp_costbase = 'W'
               THEN (@n_qty / @d_temp_costmasterunits) * Convert(dec(21,6),@n_StdGrossWgt)
               WHEN @c_temp_costbase = 'R' and @n_StdGrossWgt > @n_StdCube
               THEN (@n_qty / @d_temp_costmasterunits) * Convert(dec(21,6),@n_StdGrossWgt)
               WHEN @c_temp_costbase = 'R' and @n_StdGrossWgt <= @n_StdCube
               THEN (@n_qty / @d_temp_costmasterunits) * Convert(dec(21,6),@n_StdCube)
               WHEN @c_temp_costbase = 'P' and @c_temp_base = 'P'
               THEN 1.0
               ELSE 0.0 END )
               SELECT @d_temp_sysgencost = @d_temp_costrate * @d_temp_costunits
               SELECT @d_temp_cost = @d_temp_sysgencost
               SELECT @n_temp_sysgencharge = @n_temp_debit
               EXECUTE   nspg_getkey
               'AccumulatedCharges'
               , 10
               , @c_temp_accumulatedchargeskey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
               , 0
               , 1
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62407
                  SELECT @c_errmsg = 'nspItrnAddDWBill: ' + dbo.fnc_RTrim(@c_errmsg)
               END
           
               INSERT AccumulatedCharges ( AccumulatedChargesKey,
                  Descrip,
                  StorerKey,
                  Sku,
                  Lot,
                  Id,
                  UOMShow,
                  TariffKey,
                  TariffDetailKey,
                  TaxGroupKey,
                  Rate,
                  Base,
                  MasterUnits,
                  SystemGeneratedCharge,
                  Debit,
                  BilledUnits,
                  ChargeType,
                  BillFromDate,
                  BillThruDate,
                  SourceKey,
                  SourceType,
                  GLDistributionKey,
                  CostRate,
                  CostBase,
                  CostMasterUnits,
                  CostUOMShow,
                  CostSystemGeneratedCharge,
                  Cost,
                  CostUnits )
               VALUES ( @c_temp_accumulatedchargeskey,
                  @c_temp_descrip,
                  @c_temp_storerkey,
                  @c_temp_sku,
                  @c_temp_lot,
                  @c_temp_id,
                  @c_temp_UOMShow,
                  @c_temp_tariffkey,
                  @c_temp_tariffdetailkey,
                  @c_temp_taxgroupkey,
                  @n_temp_rate,
                  @c_temp_base,
                  @n_temp_masterunits,
                  @n_temp_sysgencharge,
                  @n_temp_debit,
                  @n_temp_billedunits,
                  @c_temp_chargetype,
                  @d_temp_billfromdate,
                  @d_temp_billthrudate,
                  @c_temp_sourcekey,
                  @c_temp_sourcetype,
                  @c_temp_gldistributionkey,
                  @d_temp_costrate,
                  @c_temp_costbase,
                  @d_temp_costmasterunits,
                  @c_temp_costuomshow,
                  @d_temp_sysgencost,
                  @d_temp_cost,
                  @d_temp_costunits )
               SELECT @n_err = @@ERROR
               IF @n_err <> 0 -- Some fatal error occurred
               BEGIN
                  SELECT @n_continue = 3 
                  SELECT @n_err= 62408 --75004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into AccumulatedCharges failed (nspItrnAddDWBill)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END 
               GETNEXTROW:
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  FETCH NEXT FROM cTariffDetailLines 
                  INTO @c_temp_tariffdetailkey, @c_temp_chargetype, @c_temp_descrip, @n_temp_rate, @c_temp_base, 
                  @n_temp_masterunits, @c_temp_UOMShow, @c_temp_taxgroupkey, @c_temp_gldistributionkey, 
                  @c_temp_roundmasterunits, @d_uom1mult, @d_uom2mult, @d_uom3mult, @d_uom4mult,
                  @d_temp_costrate, @c_temp_costbase, @d_temp_costmasterunits, @c_temp_costuomshow
                  SELECT @n_cnt = @@ROWCOUNT
               END
            END /* WHILE (@n_cnt = 1 AND (@n_continue = 1 or @n_continue = 2)) */
         END /* end IF @n_continue = 1 or @n_continue = 2 */
         IF @b_cursor_opened = 1 -- Only deallocate the cursor if it was opened.
         BEGIN
            CLOSE cTariffDetailLines
            DEALLOCATE cTariffDetailLines
         END
      END -- @n_continue = 1 or @n_continue = 2
   END -- @n_continue =1 or @n_continue=2
   /* #INCLUDE <SPIADWB2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         -- Notes: Original codes do not have COMMIT TRAN, error will be handled by parent
         -- WHILE @@TRANCOUNT > @n_starttcnt
         --    COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR 
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddDWBill'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END         
   ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END 

END

GO