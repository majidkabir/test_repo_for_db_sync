SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_nonpdapickticket                               */
/* Creation Date: 19-Jul-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#284948 - VFTBL Non RDT Pickticket                      */
/*                                                                      */
/* Input Parameters: @c_wavekey, @c_orderkey_start, @c_orderkey_end     */
/*                                                                      */
/* Called By:  dw = r_dw_nonpds_pickticket                              */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 29-JUL-2013  YTWan    1.1  SOS#284948 - NonRDTPickticket. (Wan01)    */
/* 09-AUG-2017  JHTAN    1.2  IN00432086 Duplicate line on pick ticket  */
/*                            report (JHTAN01)                          */
/* 28-Jan-2019  TLTING_ext 1.3 enlarge externorderkey field length      */
/************************************************************************/

CREATE   PROC [dbo].[nsp_nonpdapickticket] (
   	@c_wavekey 			NVARCHAR(10)
   ,	@c_orderkey_start NVARCHAR(30)
   ,	@c_orderkey_end 	NVARCHAR(30)
)
as
BEGIN -- main
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     int
      	, @n_starttcnt    int
      	, @b_success      int
      	, @n_err          int
      	, @c_errmsg       NVARCHAR(255)
      	, @local_n_err    int
      	, @local_c_errmsg	NVARCHAR(255)
      	, @c_status    	NVARCHAR(10)
      	, @c_orderkey     NVARCHAR(10)
      	, @c_pickslipno   NVARCHAR(10)
      	, @n_cnt          int
      	, @c_reprint      NVARCHAR(1)
      	, @c_locationtype NVARCHAR(10)
      	, @c_price        NVARCHAR(1)

   select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
          @local_n_err = 0, @local_c_errmsg = ''

   CREATE TABLE #RESULT (
      pickslipno 		NVARCHAR(10),
      orderkey 		NVARCHAR(10),
      externorderkey NVARCHAR(50),   --tlting_ext
      c_country 		NVARCHAR(30),
      loc 				NVARCHAR(10),
      sku 				NVARCHAR(20),
      qty 				int,
      notes2 			NVARCHAR(255),
      reprint 			NVARCHAR(1),
      logicalloc 		NVARCHAR(18),
      uccno 			NVARCHAR(20),
      locationtype 	NVARCHAR(20),
      price 			NVARCHAR(1)
   --(Wan01) - START
   ,  C_Company      NVARCHAR(45)
   ,  Userdefine09   NVARCHAR(10)
   ,  Route          NVARCHAR(10)
   ,  DischargePlace NVARCHAR(20)
   ,  Style          NVARCHAR(20)
   ,  Color          NVARCHAR(20)
   ,  Q              NVARCHAR(1)
   ,  Size           NVARCHAR(5)
   ,  Measurement    NVARCHAR(5)
   --(Wan01) - END
   )

   if exists (select 1 from replenishment (nolock) where replenno = @c_wavekey and (confirmed = 'N' or confirmed = 'S'))
   BEGIN
      SELECT * FROM #RESULT
      DROP TABLE #RESULT
      RETURN
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN -- 1
      select @c_orderkey = ''

      -- Start : June
      -- while (1=1)
      -- begin -- while: 1
            /*
            SELECT @c_reprint = 'N', @c_price = 'N'
            select @c_orderkey = min(orderkey)
            from wavedetail (nolock)
            where wavekey = @c_wavekey
               and orderkey between @c_orderkey_start and @c_orderkey_end
               and orderkey > @c_orderkey

            if isnull(@c_orderkey, '0') = '0'
               break
            */

      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      select orderkey
      from   wavedetail (nolock)
      where  wavekey = @c_wavekey
      and    orderkey between @c_orderkey_start and @c_orderkey_end

      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_orderkey

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @c_reprint = 'N', @c_price = 'N'
         -- End : June
         --(Wan01) - START
         --if exists (select 1 from orders WITH (nolock)
         --           where orderkey = @c_orderkey and c_country = 'HK' and userdefine02 = 'FW') or
         --   exists (select 1 from orderdetail WITH (nolock)
         --           where orderkey = @c_orderkey and substring(sku, 15, 1) = '3')
         IF EXISTS ( SELECT 1
                     FROM ORDERS      WITH (NOLOCK)
                     JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
                     JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                                    AND(ORDERDETAIL.Sku = SKU.Sku)
                     LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'VFSUBSBU')
                                                      AND(CODELKUP.Code = SKU.BUSR3)
                                                      AND(CODELKUP.UDF01= 'FW')
                     WHERE ORDERS.Orderkey = @c_Orderkey
                     AND   (SUBSTRING(SKU.Sku,12,1) = 'S'
                     OR    (ORDERS.C_Country IN ('HK', 'MO') AND CODELKUP.Code IS NOT NULL))
                   )
         --(Wan01) - END
         begin -- exists

            SELECT @c_pickslipno = MAX(pickslipno)
            FROM Pickdetail WITH (NOLOCK)
--            JOIN Loc WITH (NOLOCK) ON Pickdetail.Loc = Loc.Loc              --(Wan01)
            WHERE Pickdetail.Orderkey = @c_orderkey
            --AND  (CartonType <> 'FCP' OR CartonType IS NULL)                --(Wan01)

            IF (dbo.fnc_RTrim(@c_pickslipno) = '' OR dbo.fnc_RTrim(@c_pickslipno) IS NULL)
            BEGIN
               EXECUTE nspg_getkey
                  'PickSlip' ,
                  9 ,
                  @c_pickslipno   Output ,
                  @b_success      = @b_success output,
                  @n_err          = @n_err output,
                  @c_errmsg       = @c_errmsg output

               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 77301
                  SELECT @local_c_errmsg = convert(char(5),@local_n_err)
                  SELECT @local_c_errmsg = ': PickSlip Generation failed. (nsp_nonpdapickticket) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                  BREAK
               END
               ELSE
               BEGIN
                  SELECT @c_pickslipno = 'P' + @c_pickslipno
               END
            END -- (dbo.fnc_RTrim(@c_pickslipno) = '' OR dbo.fnc_RTrim(@c_pickslipno) IS NULL)
            ELSE
            BEGIN
               SELECT @c_reprint = 'Y'
            END

            -- update pickdetail
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET    PickSlipNo = @c_pickslipno,
                   EditWho    = sUser_sName(),
                   EditDate   = GetDate(),
                   TrafficCop = Null -- June
            WHERE orderkey = @c_orderkey
               AND (PickSlipNo IS NULL or PickSlipNo = '')
--               AND (CartonType <> 'FCP' OR CartonType IS NULL)              --(Wan01)

            SELECT @local_n_err = @@error, @n_cnt = @@rowcount
            IF @local_n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @local_n_err = 77301
               SELECT @local_c_errmsg = convert(char(5),@local_n_err)
               SELECT @local_c_errmsg = ': Update of PICKDETAIL table failed. (nsp_nonpdapickticket) ' + ' ( ' +
                  ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
               BREAK
            END

            -- create packheader
            if not exists (select 1 from packheader (nolock) where pickslipno = @c_pickslipno)
            begin -- not exists
               INSERT INTO PACKHEADER (PickSlipNo,
                     Storerkey,
                     Route,
                     Orderkey,
                     OrderRefNo,
                     Loadkey,
                     Consigneekey)
               SELECT  @c_pickslipno,
                  ORDERS.Storerkey,
                  ORDERS.Route,
                  ORDERS.Orderkey,
                  ORDERS.ExternOrderkey,
                  @c_wavekey,
                  ORDERS.Consigneekey
               FROM ORDERS (NOLOCK)
               WHERE OrderKey = @c_orderkey

               SELECT @local_n_err = @@error, @n_cnt = @@rowcount
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 77303
                  SELECT @local_c_errmsg = convert(char(5),@local_n_err)
                  SELECT @local_c_errmsg = ': Insert of PACKHEADER table failed. (nsp_nonpdapickticket) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                  BREAK
               END
            end -- not exists

            -- update orders to pick in process
            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               UPDATE  ORDERS
               SET   Status   = '3',
                     EditWho  = sUser_sName(),
                     EditDate = GetDate(),
                     TrafficCop = NULL -- June
               WHERE   Orderkey = @c_orderkey

               SELECT @local_n_err = @@error, @n_cnt = @@rowcount
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 77304
                  SELECT @local_c_errmsg = convert(char(5),@local_n_err)
                  SELECT @local_c_errmsg = ': Update of Orders table failed. (nsp_nonpdapickticket) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                  BREAK
               END
            END

            -- insert into pickinginfo
            if not exists (select 1 from pickinginfo (nolock) where pickslipno = @c_pickslipno)
            BEGIN
               INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID)
               VALUES ( @c_pickslipno, GetDate(), sUser_sName())

               SELECT @local_n_err = @@error, @n_cnt = @@rowcount
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 77302
                  SELECT @local_c_errmsg = convert(char(5),@local_n_err)
                  SELECT @local_c_errmsg = ': Insert of PICKINGINFO table failed. (nsp_nonpdapickticket) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                  BREAK
               END
            END

            -- price label
            if exists (select 1 from orderdetail (nolock) where userdefine05 > '0' and orderkey = @c_orderkey)
            BEGIN
               select @c_price = 'Y'
            END

            -- insert into result table
            insert #result
         --(Wan01) - START
            (  pickslipno
            ,  orderkey
            ,  externorderkey
            ,  c_country
            ,  loc
            ,  sku
            ,  qty
            ,  notes2
            ,  reprint
            ,  logicalloc
            ,  uccno
            ,  locationtype
            ,  price
            ,  C_Company
            ,  Userdefine09
            ,  Route
            ,  DischargePlace
            ,  Style
            ,  Color
            ,  Q
            ,  Size
            ,  Measurement
            )
            select @c_pickslipno
            ,  @c_orderkey
            ,  externorderkey = ISNULL(RTRIM(o.externorderkey),'')
            ,  c_country      = ISNULL(RTRIM(o.c_country),'')
            ,  p.loc
            ,  ''
            ,  SUM(p.qty)
            ,  ISNULL(RTRIM(convert(NVARCHAR(255), o.notes2)),'')
            ,  @c_reprint
            ,  logicallocation = ISNULL(RTRIM(l.logicallocation),'')
            ,  ''    --(JHTAN01) ISNULL(u.uccno,'')
            ,  locationtype = ISNULL(RTRIM(l.locationtype),'')
            ,  @c_price
            ,  C_Company    = ISNULL(RTRIM(o.C_Company),'')
            ,  UserDefine09 = ISNULL(RTRIM(o.UserDefine09),'')
            ,  Route        = ISNULL(RTRIM(o.Route),'')
            ,  DischargePlace= ISNULL(RTRIM(o.DischargePlace),'')
            ,  style = ISNULL(RTRIM(s.style),'')
            ,  color = ISNULL(RTRIM(s.color),'')
            ,  q     = SUBSTRING(s.sku,12,1)
            ,  size  = ISNULL(RTRIM(s.size),'')
            ,  measurement = ISNULL(RTRIM(s.measurement),'')
            from pickdetail p WITH (Nolock)
            join orders o WITH (nolock) on p.orderkey = o.orderkey and p.status < '4' ---'5'
            join loc l WITH (nolock) on p.loc = l.loc
            JOIN SKU s WITH (NOLOCK) ON (p.Storerkey = s.Storerkey) AND (p.Sku = s.Sku)   --(Wan01)
            left outer join ucc u WITH (nolock) on p.storerkey = u.storerkey
                                                and p.sku = u.sku
                                                and p.lot = u.lot
                                                and p.loc = u.loc
                                                and u.wavekey = @c_wavekey
            where o.orderkey = @c_orderkey
            group by
               ISNULL(RTRIM(o.externorderkey),'')
            ,  ISNULL(RTRIM(o.c_country),'')
            ,  p.loc
            --,  p.sku
            ,  convert(NVARCHAR(255), o.notes2)
            ,  ISNULL(RTRIM(l.logicallocation),'')
            --(JHTAN01),  u.uccno
            ,  ISNULL(RTRIM(l.locationtype),'')
            ,  ISNULL(RTRIM(o.C_Company),'')
            ,  ISNULL(RTRIM(o.UserDefine09),'')
            ,  ISNULL(RTRIM(o.Route),'')
            ,  ISNULL(RTRIM(o.DischargePlace),'')
            ,  ISNULL(RTRIM(s.style),'')
            ,  ISNULL(RTRIM(s.color),'')
            ,  SUBSTRING(s.sku,12,1)
            ,  ISNULL(RTRIM(s.size),'')
            ,  ISNULL(RTRIM(s.measurement),'')
               --(Wan01)  -- END
         end -- exists

          -- Start : June
         FETCH NEXT FROM pick_cur INTO @c_orderkey
          -- End : June
      end -- WHILE

      -- Start : June
      CLOSE pick_cur
      DEALLOCATE pick_cur
      -- End : June
   END -- 1

   IF @n_continue=3  -- error occured - process and return
   BEGIN
      DROP TABLE #RESULT
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_nonpdapickticket'
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
      SELECT
      --(Wan01)  -- START
            pickslipno
         ,  orderkey
         ,  externorderkey
         ,  c_country
         ,  loc
         ,  sku
         ,  qty
         ,  notes2
         ,  reprint
         ,  logicalloc
         ,  uccno
         ,  locationtype
         ,  price
         ,  C_Company
         ,  Userdefine09
         ,  Route
         ,  DischargePlace
         ,  Style
         ,  Color
         ,  Q
         ,  Size
         ,  Measurement
      --(Wan01)  -- END
      FROM #RESULT
      DROP TABLE #RESULT
      RETURN
   END
END -- main

GO