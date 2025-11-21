SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillSetInvoiceNumbers                           */
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

CREATE PROCEDURE  [dbo].[nspBillSetInvoiceNumbers] (
@c_InvoiceBatchKey  NVARCHAR(10)
,              @n_totinvoices      int        OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_cnt int              ,    /* variable to hold @@ROWCOUNT */
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int              -- Debug mode
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0, @n_err2=0
   DECLARE @dt datetime
   SELECT @n_totinvoices = 0, @dt = getdate()
   SELECT @b_debug = 0
   IF CHARINDEX('DS_IN', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_IN', @c_errmsg) + 5, 1) )
      IF @b_debug not in (1,2)
      BEGIN
         SELECT @b_debug = 0
      END
   ELSE
      BEGIN
         SELECT 'Set Invoice Numbers started               ', GetDate()
         SELECT @dt = getdate()
      END
   END
   /* #INCLUDE <SPCRSC1.SQL> */
   DECLARE @n_rows int, @c_invoicekey NVARCHAR(10), @c_sql NVARCHAR(255), @c_sql_add NVARCHAR(255),
   @c_curStorerKey NVARCHAR(15), @c_curChargeType NVARCHAR(10), @c_curTariffKey NVARCHAR(10),
   @c_curGroup NVARCHAR(50), @c_curInvoiceStrategy NVARCHAR(10), @b_DoLoop NVARCHAR(1)
   SELECT @c_curStorerKey = master.dbo.fnc_GetCharASCII(14), @c_curChargeType = master.dbo.fnc_GetCharASCII(14), @c_curTariffKey = master.dbo.fnc_GetCharASCII(14)
   SELECT Distinct StorerKey
   INTO #Bill_Storers
   FROM BILL_ACCUMULATEDCHARGES
   WHERE InvoiceBatch = @c_InvoiceBatchKey
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Getting List of Storers Failed! (nspBillSetInvoiceNumbers)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Storers Found! (nspBillSetInvoiceNumbers)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   WHILE @n_continue in (1,2)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_curStorerKey = #Bill_Storers.StorerKey,
      @c_curInvoiceStrategy = STORERBILLING.InvoiceNumberStrategy
      FROM #Bill_Storers, STORERBILLING
      WHERE #Bill_Storers.StorerKey > @c_curStorerKey
      and #Bill_Storers.StorerKey = STORERBILLING.StorerKey
      ORDER BY #Bill_Storers.StorerKey
      SELECT @n_cnt = @@ROWCOUNT
      SET ROWCOUNT 0
      IF @n_cnt = 0 BREAK
      IF IsNull(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_curInvoiceStrategy)), '') = ''
      OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_curInvoiceStrategy)) = '0'
      BEGIN
         SELECT @c_curInvoiceStrategy = '1'
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_curInvoiceStrategy)) NOT IN ('1','2','3','4','5')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Invoice Number Strategy. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug <> 0
      BEGIN
         SELECT '@c_curStorerKey', @c_curStorerKey, '@c_curInvoiceStrategy', @c_curInvoiceStrategy, 'curTime', getdate()
         SELECT @dt = getdate()
      END
      SELECT @c_curGroup = master.dbo.fnc_GetCharASCII(14), @b_DoLoop = '1'
      WHILE @n_continue in (1,2)
      BEGIN
         SET ROWCOUNT 1
         IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '1'
         BEGIN
            SELECT @c_curChargeType = ChargeType,
            @c_curGroup = (CASE Upper(ChargeType)
            WHEN 'IS' THEN 'HI'
            WHEN 'MI' THEN 'HI'
            WHEN 'MH' THEN 'HI'
            WHEN 'MO' THEN 'HO'
            WHEN 'MR' THEN 'RS'
         ELSE ChargeType END)
            FROM BILL_ACCUMULATEDCHARGES
            WHERE StorerKey = @c_curStorerKey
            AND @c_curGroup < (CASE Upper(ChargeType)
            WHEN 'IS' THEN 'HI'
            WHEN 'MI' THEN 'HI'
            WHEN 'MH' THEN 'HI'
            WHEN 'MO' THEN 'HO'
            WHEN 'MR' THEN 'RS'
         ELSE ChargeType END)
            ORDER BY 2
         END
      ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '2'
         BEGIN
            SELECT @c_curChargeType = ChargeType,
            @c_curGroup = CASE Upper(ChargeType)
            WHEN 'MI' THEN 'IS'
            WHEN 'MH' THEN 'HI'
            WHEN 'MO' THEN 'HO'
            WHEN 'MR' THEN 'RS'
         ELSE ChargeType END
            FROM BILL_ACCUMULATEDCHARGES
            WHERE StorerKey = @c_curStorerKey
            AND @c_curGroup < CASE Upper(ChargeType)
            WHEN 'MI' THEN 'IS'
            WHEN 'MH' THEN 'HI'
            WHEN 'MO' THEN 'HO'
            WHEN 'MR' THEN 'RS'
         ELSE ChargeType END
            ORDER BY 2
         END
      ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '3'
         BEGIN
            IF @b_DoLoop = '1'
            SELECT @b_DoLoop = '2'
         ELSE
            SELECT @b_DoLoop = '0'
         END
      ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '4'
         BEGIN
            SELECT @c_curChargeType = ChargeType, @c_curTariffKey = TariffKey,
            @c_curGroup = (ChargeType + TariffKey)
            FROM BILL_ACCUMULATEDCHARGES
            WHERE StorerKey = @c_curStorerKey
            AND (ChargeType + TariffKey) > @c_curGroup
            ORDER BY (ChargeType + TariffKey)
         END
      ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '5'
         BEGIN
            SELECT @c_curChargeType = ChargeType,
            @c_curGroup = (CASE Upper(ChargeType)
            WHEN 'IS' THEN 'HI'
            WHEN 'MI' THEN 'HI'
            WHEN 'MH' THEN 'HI'
            WHEN 'MO' THEN 'HO'
            WHEN 'MR' THEN 'RS'
         ELSE ChargeType END)
            + (CASE WHEN ITRNSourceType = 'RECEIPT'
         THEN ITRNSourceKey ELSE ' ' END)
            FROM BILL_ACCUMULATEDCHARGES
            WHERE StorerKey = @c_curStorerKey
            AND @c_curGroup < (CASE Upper(ChargeType)
            WHEN 'IS' THEN 'HI'
            WHEN 'MI' THEN 'HI'
            WHEN 'MH' THEN 'HI'
            WHEN 'MO' THEN 'HO'
            WHEN 'MR' THEN 'RS'
         ELSE ChargeType END)
            + (CASE WHEN ITRNSourceType = 'RECEIPT'
         THEN ITRNSourceKey ELSE ' ' END)
            ORDER BY 2
         END
         SELECT @n_cnt = @@ROWCOUNT
         SET ROWCOUNT 0
         IF @b_DoLoop = '0' OR @n_cnt = 0 BREAK
         EXECUTE nspg_getkey 'InvoiceKey', 10, @c_invoicekey OUTPUT,
         @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF @b_debug <> 0
         BEGIN
            SELECT '@c_curGroup', @c_curGroup, '@c_invoicekey', @c_invoicekey, 'Elapsed',DateDiff(ss,@dt,getdate())
            SELECT @dt= getdate()
         END
         IF @b_success = 1
         BEGIN
            SELECT @c_sql = 'UPDATE BILL_ACCUMULATEDCHARGES '
            + ' SET InvoiceKey=N''' + @c_invoicekey + ''''
            + ' WHERE StorerKey=N''' + @c_curStorerKey + ''''
            SELECT @c_sql_add = ''
            IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '1'
            BEGIN
               SELECT @c_sql = @c_sql + ' AND N''' + @c_curGroup + ''' = CASE'
               + ' WHEN ChargeType IN ("IS","MI","MH") THEN "HI"'
               + ' WHEN ChargeType IN ("MO") THEN "HO"'
               + ' WHEN ChargeType IN ("MR") THEN "RS"'
               + ' ELSE ChargeType END'
            END
         ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '2'
            BEGIN
               SELECT @c_sql = @c_sql + ' AND N''' + @c_curGroup+ ''' = CASE Upper(ChargeType) '
               + ' WHEN "MI" THEN "IS"'
               + ' WHEN "MH" THEN "HI"'
               + ' WHEN "MO" THEN "HO"'
               + ' WHEN "MR" THEN "RS"'
               + ' ELSE ChargeType END'
            END
         ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '3'
            BEGIN
               SELECT @c_sql = @c_sql
            END
         ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '4'
            BEGIN
               SELECT @c_sql = @c_sql
               + ' AND ChargeType = N''' + @c_curChargeType + ''''
               + ' AND TariffKey = N''' + @c_curTariffKey + ''''
            END
         ELSE IF dbo.fnc_RTrim(@c_curInvoiceStrategy) = '5'
            BEGIN
               SELECT @c_sql = @c_sql + ' AND N''' + @c_curGroup + ''' = '
               SELECT @c_sql_add = '(CASE'
               + ' WHEN ChargeType IN ("IS","MI","MH") THEN "HI"'
               + ' WHEN ChargeType IN ("MO") THEN "HO"'
               + ' WHEN ChargeType IN ("MR") THEN "RS"'
               + ' ELSE ChargeType END) + (CASE '
               + ' WHEN ITRNSourceType = "RECEIPT"'
               + ' THEN ITRNSourceKey ELSE " " END)'
            END
            IF @b_debug = 1
            BEGIN
               SELECT @c_sql
               SELECT @c_sql_add
            END
            EXECUTE (@c_sql + @c_sql_add)
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating Invoice Keys for Strategy "+dbo.fnc_RTrim(@c_curInvoiceStrategy) +". (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         ELSE
            BEGIN
               SELECT @n_totinvoices = @n_totinvoices + 1
               IF @b_debug = 1
               BEGIN
                  SELECT 'Set invoce rows:', @n_cnt, 'Total invoices', @n_totinvoices, 'Elapsed',DateDiff(ss,@dt,getdate())
                  SELECT @dt=getdate()
               END
            END
         END
      ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Get Key failed. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END -- while invoice group loop
   END -- while storerkey loop
   IF @n_continue in (1,2)
   BEGIN
      IF EXISTS (SELECT 1 FROM BILL_ACCUMULATEDCHARGES WHERE IsNull(dbo.fnc_RTrim(dbo.fnc_LTrim(InvoiceKey)),'') = '')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Some Invoice Keys are missing for Strategy "+dbo.fnc_RTrim(@c_curInvoiceStrategy) +". (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      SELECT @n_totinvoices = 0
   END
ELSE
   BEGIN
      SELECT @b_success = 1
   END
   IF @b_debug <> 0
   BEGIN
      SELECT 'Set Invoice Numbers completed at ',  GetDate(), 'Number of invoices:', @n_totinvoices
   END
END


GO