SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillContainer                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspBillContainer]
@c_sourcetype    NVARCHAR(30)
,            @c_sourcekey     NVARCHAR(20)
,            @c_containertype NVARCHAR(20)
,            @n_containerqty  int
,            @c_storerkey     NVARCHAR(15)
,            @b_Success       int         OUTPUT
,            @n_err           int         OUTPUT
,            @c_errmsg        NVARCHAR(250)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue int
   ,      @n_err2 int              -- For Additional Error Detection
   ,      @c_preprocess NVARCHAR(250)  -- preprocess
   ,      @c_pstprocess NVARCHAR(250)  -- post process
   ,      @n_cnt int
   ,      @b_debug int
   SELECT @n_continue=1, @b_success=0, @n_err = 1, @c_errmsg=""
   SELECT @b_debug = 0
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
   ,      @d_temp_rate               decimal(22,6)
   ,      @c_temp_base               NVARCHAR(1)
   ,      @d_temp_masterunits        decimal(12,6)
   ,      @d_temp_sysgencharge       decimal(28,6)
   ,      @d_temp_debit              decimal(28,6)
   ,      @d_temp_billedunits        decimal(21,6)
   ,      @c_temp_chargetype         NVARCHAR(10)
   ,      @d_temp_billthrudate       datetime
   ,      @d_temp_billfromdate       datetime
   ,      @c_temp_sourcekey          NVARCHAR(20)
   ,      @c_temp_sourcetype         NVARCHAR(30)
   ,      @c_temp_gldistributionkey  NVARCHAR(10)
   ,      @c_temp_roundmasterunits   NVARCHAR(10)
   ,      @d_temp_costrate           decimal(22,6)
   ,      @c_temp_costbase           NVARCHAR(1)
   ,      @d_temp_costmasterunits    decimal(12,6)
   ,      @c_temp_costuomshow        NVARCHAR(10)
   ,      @d_temp_sysgencost         decimal(28,6)
   ,      @d_temp_cost               decimal(28,6)
   ,      @d_temp_costunits          decimal(21,6)
   /* #INCLUDE <SPIADWB1.SQL> */
   IF (SELECT NSQLValue FROM NSQLConfig (nolock) WHERE ConfigKey = "WAREHOUSEBILLING") <> "1"
   BEGIN
      SELECT @n_continue = 4
      SELECT @c_errmsg = "Warehouse Billing turned OFF (nspBillContainer)"
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @b_debug = 1 SELECT 'Arguments are: ', @c_sourcetype, @c_sourcekey, @c_containertype, @n_containerqty, @c_storerkey
      IF IsNull(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sourcekey)), '') = '' or
      IsNull(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)), '') = '' or
      IsNull(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sourcetype)), '') = '' or
      @n_containerqty <= 0
      BEGIN
         SELECT @n_continue = 3 , @n_err = 86900
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": One of the arguments is invalid. (nspBillContainer)"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF not exists (SELECT 1 FROM STORERBILLING (nolock) WHERE StorerKey = @c_storerkey)
      BEGIN
         SELECT @n_continue = 3 , @n_err = 86901
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer does not exists. (nspBillContainer)"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_RTrim(@c_sourcetype) = 'ASN'
      BEGIN
         SELECT @c_temp_chargetype = 'CI'
      END
   ELSE IF dbo.fnc_RTrim(@c_sourcetype) IN ('SO', 'CNT')
      BEGIN
         SELECT @c_temp_chargetype = 'CO'
      END
   ELSE
      BEGIN
         SELECT @n_continue = 3 , @n_err = 86902
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unknown Document Type. (nspBillContainer)"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT Descr, Rate, TaxGroupKey, GLDistributionKey, CostRate,
      ContainerBillingKey
      INTO #Charges
      FROM CONTAINERBILLING (nolock)
      WHERE dbo.fnc_RTrim(DocType) = dbo.fnc_RTrim(@c_sourcetype)
      and dbo.fnc_RTrim(ContainerType) = dbo.fnc_RTrim(@c_containertype)
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0 -- Some fatal error occurred
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert into temp table failed (nspBillContainer)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = "No Container Billing Charges Found (nspBillContainer)"
      END
   ELSE IF @b_debug = 1   SELECT * FROM #Charges
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_sourcetype = ( CASE @c_sourcetype
      WHEN 'ASN' THEN 'ASN/Receipt'
      WHEN 'SO'  THEN 'ShipmentOrder'
      WHEN 'CNT' THEN 'ContainerManifest'
   ELSE @c_sourcetype  END )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_containerbillingkey NVARCHAR(10)
      SELECT @c_containerbillingkey = master.dbo.fnc_GetCharASCII(14)
      WHILE @n_continue = 1 or @n_continue = 2
      BEGIN
         SET ROWCOUNT 1
         SELECT @c_temp_descrip = Descr,
         @d_temp_rate = Rate,
         @c_temp_taxgroupkey = TaxGroupKey,
         @c_temp_gldistributionkey = GLDistributionKey,
         @d_temp_costrate = CostRate,
         @c_containerbillingkey = ContainerBillingKey
         FROM #Charges
         WHERE ContainerBillingKey > @c_ContainerBillingKey
         ORDER BY ContainerBillingKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         SET ROWCOUNT 0
         IF @n_err <> 0 -- Some fatal error occurred
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Select from temp charge table failed (nspBillContainer)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE IF @n_cnt = 0
         BEGIN
            BREAK
         END
         EXECUTE   nspg_getkey
         "AccumulatedCharges"
         , 10
         , @c_temp_accumulatedchargeskey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         IF @b_success = 0
         BEGIN
            SELECT @n_continue = 3
            BREAK
         END
         SELECT @c_temp_storerkey = @c_storerkey,
         @c_temp_UOMShow = 'Container',
         @c_temp_base = 'Q',
         @d_temp_masterunits = 1.0,
         @d_temp_sysgencharge = @n_containerqty * @d_temp_rate ,
         @d_temp_debit = @n_containerqty * @d_temp_rate,
         @d_temp_billedunits = @n_containerqty,
         @d_temp_billfromdate = GetDate(),
         @d_temp_billthrudate = GetDate(),
         @c_temp_sourcekey = @c_sourcekey,
         @c_temp_sourcetype = @c_sourcetype,
         @c_temp_costbase = 'Q',
         @d_temp_costmasterunits = 1.0,
         @c_temp_costuomshow = 'Container',
         @d_temp_sysgencost = @n_containerqty * @d_temp_costrate ,
         @d_temp_cost = @n_containerqty * @d_temp_costrate ,
         @d_temp_costunits = @n_containerqty
         IF @b_debug = 1
         BEGIN
            PRINT 'Ready to INSERT '
            SELECT @c_temp_accumulatedchargeskey,  @c_temp_descrip,  @c_temp_storerkey,
            @c_temp_UOMShow, @c_temp_taxgroupkey,
            @d_temp_rate, @c_temp_base, @d_temp_masterunits, @d_temp_sysgencharge,
            @d_temp_debit, @d_temp_billedunits, @c_temp_chargetype,
            @d_temp_billfromdate, @d_temp_billthrudate, @c_temp_sourcekey,
            @c_temp_sourcetype, @c_temp_gldistributionkey, @d_temp_costrate,
            @c_temp_costbase, @d_temp_costmasterunits, @c_temp_costuomshow,
            @d_temp_sysgencost, @d_temp_cost, @d_temp_costunits
         END
         INSERT AccumulatedCharges ( AccumulatedChargesKey, Descrip, StorerKey,
         UOMShow, TaxGroupKey,
         Rate, Base, MasterUnits, SystemGeneratedCharge, Debit,  BilledUnits,
         ChargeType, BillFromDate, BillThruDate,
         SourceKey, SourceType, GLDistributionKey,
         CostRate, CostBase, CostMasterUnits, CostUOMShow,
         CostSystemGeneratedCharge, Cost, CostUnits )
         VALUES ( @c_temp_accumulatedchargeskey,  @c_temp_descrip,  @c_temp_storerkey,
         @c_temp_UOMShow, @c_temp_taxgroupkey,
         @d_temp_rate, @c_temp_base, @d_temp_masterunits, @d_temp_sysgencharge,
         @d_temp_debit, @d_temp_billedunits, @c_temp_chargetype,
         @d_temp_billfromdate, @d_temp_billthrudate, @c_temp_sourcekey,
         @c_temp_sourcetype, @c_temp_gldistributionkey, @d_temp_costrate,
         @c_temp_costbase, @d_temp_costmasterunits, @c_temp_costuomshow,
         @d_temp_sysgencost, @d_temp_cost, @d_temp_costunits )
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 -- Some fatal error occurred
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert into AccumulatedCharges failed (nspBillContainer)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END -- while loop
   END -- insert accumulated charges
   /* #INCLUDE <SPIADWB2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, "nspBillContainer"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END
END


GO