SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspExportMove                                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 2007-07-16   TLTING        SQL2005, Put ' in status check            */
/* 26-Nov-2013  TLTING        Change user_name() to SUSER_SNAME()       */
/* 02-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nsp_rfpicknpackgetpickingorder] (
   @c_storerkey   NVARCHAR(15),
   @c_wavekey     NVARCHAR(10),
   @n_orderno     int,
   @c_country     NVARCHAR(30),
   @c_zone        NVARCHAR(10)
) 
as
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

/* 25 March 2004 WANYT Timberland FBR#20720: RF Stock Take Entry */
   declare  @n_continue             int,
            @n_starttcnt            int,
            @b_success              int,
            @n_err                  int,
            @c_errmsg               NVARCHAR(255),
            @local_n_err            int,
            @local_c_errmsg         NVARCHAR(255),
            @n_cnt                  int,
            @n_rowcnt               int,
            @c_countrystatement     NVARCHAR(255),
            @c_instancestatement    NVARCHAR(255),
            @n_posstart             int,
            @n_pos                  int

   select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
          @local_n_err = 0, @local_c_errmsg = ''


   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN   
      -- build country criteria string
      
      SELECT @n_pos = 1, @n_posstart = 1
      SELECT @c_countrystatement = ''

      WHILE @n_pos <> 0 AND dbo.fnc_RTrim(@c_country) IS NOT NULL
      BEGIN 
         IF @n_posstart = 1 
            SELECT @c_countrystatement = ' AND ( '
         ELSE
            SELECT @c_countrystatement = @c_countrystatement + 'OR'

         SELECT @n_pos = CHARINDEX(',', @c_country,  @n_posstart) 
         IF @n_pos > 0 
         BEGIN
            SELECT @c_countrystatement = @c_countrystatement + ' ORDERS.C_Country = N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(@c_country, @n_posstart, @n_Pos - @n_posstart))) + ''' )'
            SELECT @n_posstart = @n_pos + 1
         END
         ELSE 
            SELECT @c_countrystatement = dbo.fnc_RTrim(@c_countrystatement) + ' ORDERS.C_Country = N''' +
                   dbo.fnc_LTrim(dbo.fnc_RTrim(RIGHT(dbo.fnc_RTrim(@c_country), LEN(@c_country)- @n_posstart + 1))) + ''' )'
      END 
      SELECT @c_instancestatement = 'AND    ORDERS.Storerkey = N''' + dbo.fnc_RTrim(@c_storerkey) + ''' ' +
                     'AND    LOC.PutawayZone  = N''' + dbo.fnc_RTrim(@c_zone) + ''' ' 
      
      CREATE TABLE #temp ( orderkey NVARCHAR(10), Zone NVARCHAR(10) )

      IF @c_wavekey = 'ALL'
      BEGIN
         SET ROWCOUNT @n_orderno
         EXECUTE (
         'INSERT INTO #temp ' + 
         'SELECT ORDERS.ORDERKEY, LOC.PutawayZone ' +   
         'FROM   ORDERS (NOLOCK), PICKDETAIL (NOLOCK) , LOC (NOLOCK) ' + 
         'WHERE  ORDERS.Orderkey = PICKDETAIL.Orderkey '+
         'AND    PICKDETAIL.Loc  = LOC.Loc '+
         'AND    PICKDETAIL.Status < "5" ' +
         @c_countrystatement + @c_instancestatement +
         'AND ORDERS.SOStatus = "0" ' + 
         'AND ORDERS.Status < "9" ' +
         'AND (ORDERS.C_Country <> "HK" OR ORDERS.Userdefine02 <> "FW") ' +
         'AND SUBSTRING(PICKDETAIL.SKU, 15, 1) <> "3" ' +   
         'AND NOT EXISTS (SELECT 1 FROM PICKORDERLOG (NOLOCK) ' +
                           'WHERE PICKORDERLOG.Orderkey = ORDERS.Orderkey ' +
                           'AND ZONE =  dbo.fnc_RTrim(N''' + @c_zone + ''')) ' +
         'GROUP BY ORDERS.ORDERKEY, LOC.PutawayZone, ORDERS.Priority ' +
         'ORDER BY ORDERS.Priority ' )
         SET ROWCOUNT 0
      END
      ELSE
      BEGIN
         SET ROWCOUNT @n_orderno
         EXECUTE (
         'INSERT INTO #temp ' + 
         'SELECT ORDERS.ORDERKEY, LOC.PutawayZone ' +   
         'FROM   ORDERS (NOLOCK), PICKDETAIL (NOLOCK) , LOC (NOLOCK) ' + 
         'WHERE  ORDERS.Orderkey = PICKDETAIL.Orderkey '+
         'AND    PICKDETAIL.Loc  = LOC.Loc '+
         'AND    PICKDETAIL.Status < "5" ' +
         @c_countrystatement + @c_instancestatement +
         'AND ORDERS.SOStatus = "0" ' + 
         'AND ORDERS.Status < "9" ' +
         'AND (ORDERS.C_Country <> "HK" OR ORDERS.Userdefine02 <> "FW") ' +
         'AND ORDERS.UserDefine09 = N''' + @c_wavekey + ''' ' +
         'AND SUBSTRING(PICKDETAIL.SKU, 15, 1) <> "3" ' +   
         'AND NOT EXISTS (SELECT 1 FROM PICKORDERLOG (NOLOCK) ' +
                           'WHERE PICKORDERLOG.Orderkey = ORDERS.Orderkey ' +
                           'AND ZONE =  dbo.fnc_RTrim(N''' + @c_zone + ''')) ' +
         'GROUP BY ORDERS.ORDERKEY, LOC.PutawayZone, ORDERS.Priority ' +
         'ORDER BY ORDERS.Priority ' )
         SET ROWCOUNT 0
      END      

      INSERT INTO PICKORDERLOG
      SELECT Orderkey, Zone, @@SPID, '0', dbo.fnc_RTrim(Suser_Sname())
      FROM #temp

      SELECT @local_n_err = @@error, @n_cnt = @@rowcount

      IF @local_n_err <> 0
      BEGIN 
         SELECT @n_continue = 3
         SELECT @local_n_err = 77301
         SELECT @local_c_errmsg = convert(char(5),@local_n_err)
         SELECT @local_c_errmsg =
         ': Insert of PICKORDERLOG table failed. (nsp_rfpicknpackgetpickingorder) ' + ' ( ' +
         ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
      END 

      IF (@n_continue = 1 OR @n_continue = 2) 
      BEGIN   
         SELECT PICKDETAIL.Orderkey,
                PICKDETAIL.Pickdetailkey,
                PICKDETAIL.Storerkey,
                PICKDETAIL.Sku,
                SKU.Descr,
                PICKDETAIL.Loc,
                PICKDETAIL.Qty,
                LOTATTRIBUTE.Lottable01,
                LOTATTRIBUTE.Lottable02,
                LOTATTRIBUTE.Lottable03,
                LOTATTRIBUTE.Lottable04,
                LOTATTRIBUTE.Lottable05,
                LOTATTRIBUTE.Lottable06,
                LOTATTRIBUTE.Lottable07,
                LOTATTRIBUTE.Lottable08,
                LOTATTRIBUTE.Lottable09,
                LOTATTRIBUTE.Lottable10,
                LOTATTRIBUTE.Lottable11,
                LOTATTRIBUTE.Lottable12,
                LOTATTRIBUTE.Lottable13,
                LOTATTRIBUTE.Lottable14,
                LOTATTRIBUTE.Lottable15,
                #temp.Zone, 
                (PICKDETAIL.Qty * SKU.StdCube) AS CBM,
                PICKDETAIL.PickSlipNo,
                NULL AS CartonNo,
                NULL AS LabelNo,
                NULL AS PICK,
                0, -- prevpick
                PICKDETAIL.OrderLineNumber,
                PICKDETAIL.Lot,
                PICKDETAIL.ID,
                PICKDETAIL.UOM,
                PICKDETAIL.UOMQty,
                PICKDETAIL.Packkey,
                LOC.LogicalLocation
         FROM  #temp JOIN PICKDETAIL (NOLOCK)
            ON #temp.Orderkey = PICKDETAIL.Orderkey
         JOIN ORDERS (NOLOCK)
            ON #temp.Orderkey = ORDERS.Orderkey
         JOIN LOTATTRIBUTE (NOLOCK)
            ON LOTATTRIBUTE.Lot = PICKDETAIL.Lot
         JOIN LOC (NOLOCK)
            ON PICKDETAIL.Loc = LOC.Loc
               AND #temp.Zone = LOC.Putawayzone 
         JOIN SKU (NOLOCK)
            ON SKU.Storerkey = PICKDETAIL.Storerkey
               AND SKU.SKU = PICKDETAIL.SKU 
          LEFT OUTER JOIN PACKDETAIL (NOLOCK)
--              ON PICKDETAIL.PickSlipNo = PACKDETAIL.PickSlipNo
--                 AND PICKDETAIL.SKU = PACKDETAIL.SKU
--                 AND PICKDETAIL.Qty = PACKDETAIL.Qty
            ON PICKDETAIL.Pickdetailkey = PACKDETAIL.RefNo
         WHERE PICKDETAIL.Status < '5'                   -- SQL2005 Put ' in status check
            AND PICKDETAIL.Qty > 0
            AND (PICKDETAIL.CartonType <> 'FCP' OR PICKDETAIL.CartonType IS NULL)
            AND PACKDETAIL.Qty IS NULL
--         ORDER BY LOC.LogicalLocation, PICKDETAIL.Loc, PICKDETAIL.Orderkey
      END   
      DROP TABLE #temp
   END 

   IF @n_continue=3  -- error occured - process and return
   BEGIN
      SELECT @b_success = 0
      IF @@trancount = 1 and @@trancount > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@trancount > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
   
      SELECT @n_err = @local_n_err
      SELECT @c_errmsg = @local_c_errmsg
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_rfpicknpackgetpickingorder"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@trancount > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO