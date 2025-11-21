SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCartonization                                   */
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
/* Date         Author        Purposes                                  */
/************************************************************************/


/*******************************************************************
* Modification History:
*
* 06/11/2002 Leo Ng  Program rewrite for IDS version 5
* *****************************************************************/

CREATE PROC    [dbo].[nspCartonization]
@c_cartonbatch  NVARCHAR(10)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int               -- Debug On Or Off
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0, @b_debug = 0
   /* #INCLUDE <SPC1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      CREATE TABLE #OP_CARTONWORK
      ( Cartonbatch NVARCHAR(10) ,
      PickDetailKey NVARCHAR(10) ,
      PickHeaderKey NVARCHAR(10) ,
      OrderKey NVARCHAR(10) ,
      OrderLineNumber NVARCHAR(10) ,
      Storerkey NVARCHAR(15) ,
      Sku NVARCHAR(20) ,
      Loc NVARCHAR(10) ,
      lot NVARCHAR(10) ,
      id NVARCHAR(18) ,
      caseid NVARCHAR(10) ,
      CartonType NVARCHAR(10) null ,
      uom NVARCHAR(10) ,
      uomqty int ,
      qty int ,
      packkey NVARCHAR(10) ,
      cartongroup NVARCHAR(10) ,
      stdcube float,
      Cube float ,
      StdGrossWgt float ,
      GrossWgt float ,
      StdNetWgt Float ,
      NetWgt Float,
      DoReplenish NVARCHAR(1) ,
      ReplenishZone NVARCHAR(10) ,
      DoCartonize   NVARCHAR(1) ,
      PickMethod NVARCHAR(1)
      )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      CREATE TABLE #OP_CARTONLINESWORK
      ( Cartonbatch NVARCHAR(10) ,
      PickDetailKey NVARCHAR(10) ,
      PickHeaderKey NVARCHAR(10) ,
      OrderKey NVARCHAR(10) ,
      OrderLineNumber NVARCHAR(10) ,
      Storerkey NVARCHAR(15) ,
      Sku NVARCHAR(20) ,
      Loc NVARCHAR(10) ,
      lot NVARCHAR(10) ,
      id NVARCHAR(18) ,
      caseid NVARCHAR(10) ,
      CartonType NVARCHAR(10) null ,
      uom NVARCHAR(10) ,
      uomqty int ,
      qty int ,
      packkey NVARCHAR(10) ,
      cartongroup NVARCHAR(10) ,
      stdcube float,
      Cube float ,
      StdGrossWgt float ,
      GrossWgt float ,
      StdNetWgt Float ,
      NetWgt Float ,
      DoReplenish NVARCHAR(1) ,
      ReplenishZone NVARCHAR(10) ,
      DoCartonize   NVARCHAR(1) ,
      PickMethod NVARCHAR(1)
      )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_maxcartontypes int
      SELECT @n_maxcartontypes = 5
      DECLARE @c_xorderkey NVARCHAR(10), @c_xcartongroup NVARCHAR(10), @c_xlastcartongroup NVARCHAR(10), @c_xlastcartonname NVARCHAR(10)
      SELECT @c_xlastcartonname = "", @c_xlastcartongroup = "", @c_xcartongroup = ""
      DECLARE @c_bigboxname NVARCHAR(10) ,
      @n_bigboxcube float ,
      @n_bigboxweight float ,
      @n_bigboxcount int
      DECLARE @c_yorderkey NVARCHAR(10), @c_ypickdetailkey NVARCHAR(10), @c_ypickheaderkey NVARCHAR(10),
      @c_yorderlinenumber NVARCHAR(5), @c_ystorerkey NVARCHAR(15), @c_ysku NVARCHAR(20), @c_yloc NVARCHAR(10),
      @c_yid NVARCHAR(18), @c_ycaseid NVARCHAR(10), @c_yuom NVARCHAR(10), @n_yuomqty int,  @c_ylot NVARCHAR(10),
      @n_yqty int, @c_ypackkey NVARCHAR(10), @c_ycartongroup NVARCHAR(10), @c_ystdcube float ,
      @c_ycartonbatch NVARCHAR(10), @n_ystdcube float, @n_ycube float, @n_ystdgrosswgt float ,
      @n_ystdnetwgt float, @n_ygrosswgt float, @n_ynetwgt float ,
      @c_yDoReplenish NVARCHAR(1), @c_yreplenishzone NVARCHAR(10), @c_ydocartonize NVARCHAR(1) ,
      @c_yoriginaluom NVARCHAR(10), @n_yNewUomQty int, @c_ypickmethod NVARCHAR(1)
      DECLARE @n_ttlcube float,              -- Total cube on this order/cartongroup combo to be cartonized.
      @n_ttlgrosswgt float ,
      @n_ttlnetwgt  float ,
      @n_ttlcount int ,
      @b_cartonizationdone int,      -- Flag to see if cartonization is done for this order/cartongroup combo.
      @c_cartonid NVARCHAR(10),
      @c_cartontype NVARCHAR(10),
      @n_qtytoputinbox int ,
      @n_cubetoputinbox float ,
      @n_grosswgttoputinbox float ,
      @n_netwgtotputinbox float ,
      @n_qtyalreadyinbox int ,
      @n_cubealreadyinbox float ,
      @n_grosswgtalreadyinbox float ,
      @n_netwgtalreadyinbox float ,
      @b_boxfull int
      DECLARE @c_nextpickdetailkey NVARCHAR(10), @c_pickdetailkey NVARCHAR(10)
      DECLARE @n_loopcounter int
      EXEC ("DECLARE CURSOR_PARTIALS_GROUP CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT ORDERKEY,CARTONGROUP FROM OP_CARTONLINES WHERE
      Cartonbatch = "
      + "N'" + @c_cartonbatch + "'"
      + "AND
      DoCartonize = 'Y'
      GROUP BY ORDERKEY,CARTONGROUP
      ORDER BY ORDERKEY,CARTONGROUP"
      )
      OPEN CURSOR_PARTIALS_GROUP
      WHILE (1=1)
      BEGIN
         SELECT @c_xlastcartongroup = @c_xcartongroup
         FETCH NEXT FROM CURSOR_PARTIALS_GROUP INTO
         @c_xorderkey, @c_xcartongroup
         IF @@FETCH_STATUS = -1
         BEGIN
            BREAK
         END
         IF @@FETCH_STATUS = 0
         BEGIN
            SELECT @b_cartonizationdone = 0
            DELETE FROM #OP_CARTONWORK
            INSERT #OP_CARTONWORK
            (Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,
            loc,lot,id,caseid,uom,uomqty,qty,packkey,cartongroup,stdcube, cube, StdGrossWgt,GrossWgt ,
            StdNetWgt, NetWgt,DoReplenish, replenishzone, docartonize,PickMethod )
            (SELECT Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,
            OP_Cartonlines.storerkey,OP_Cartonlines.sku,
            loc,lot,id,caseid,uom,uomqty,
            OP_Cartonlines.qty,OP_Cartonlines.packkey,OP_Cartonlines.cartongroup,
            Sku.stdcube,sku.stdcube*OP_Cartonlines.qty ,
            Sku.StdGrossWgt , Sku.StdGrossWgt * OP_Cartonlines.Qty ,
            Sku.StdNetWgt   , Sku.StdNetWgt * OP_Cartonlines.Qty ,
            DoReplenish, replenishzone, docartonize, PickMethod
            FROM OP_CARTONLINES,SKU
            WHERE OP_Cartonlines.Orderkey = @c_xorderkey and OP_Cartonlines.cartongroup = @c_xcartongroup
            and OP_Cartonlines.Cartonbatch = @c_cartonbatch
            and OP_Cartonlines.Storerkey=Sku.storerkey
            and OP_Cartonlines.sku = Sku.sku
            and DoCartonize = 'Y'
            )
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to populate #OP_CARTONWORK. (nspcartonization)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_xlastcartongroup <> @c_xcartongroup or @c_xlastcartonname <> @c_bigboxname
               BEGIN
                  SELECT @c_bigboxname = Cartontype ,
                  @n_bigboxcube = Cube ,
                  @n_bigboxweight = MaxWeight ,
                  @n_bigboxcount = MaxCount
                  FROM Cartonization
                  WHERE Cartonizationgroup = @c_xcartongroup AND
                  UseSequence = (SELECT MIN(useSequence) FROM Cartonization
                  WHERE CartonizationGroup = @c_xcartongroup )
                  IF @@ROWCOUNT = 1
                  BEGIN
                     SELECT @c_xlastcartonname = @c_bigboxname
                  END
               ELSE
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63602
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find CartonName/CartonGroup. (nspCartonization)"
                  END
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               DELETE FROM #op_cartonwork
               WHERE stdcube > @n_bigboxcube
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63602   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to delete oversized rows in #OP_cartonlines. (nspcartonization)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  UPDATE OP_CARTONLINES SET Cartongroup = "(OVERSIZE)", Cartontype = "(OVERSIZE)"
                  FROM SKU
                  WHERE OP_Cartonlines.Orderkey = @c_xorderkey and OP_Cartonlines.cartongroup = @c_xcartongroup
                  and OP_Cartonlines.Cartonbatch = @c_cartonbatch
                  and OP_Cartonlines.Storerkey=Sku.storerkey
                  and OP_Cartonlines.sku = Sku.sku
                  and DoCartonize = 'Y'
                  and SKU.stdcube > @n_bigboxcube
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63603   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to update oversized rows in #OP_cartonlines. (nspcartonization)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  END
               END
            END
            WHILE (@n_continue = 1 or @n_continue = 2) and @b_cartonizationdone = 0
            BEGIN
               SELECT @n_ttlcube = SUM(cube),
               @n_ttlgrosswgt = SUM(GrossWgt) ,
               @n_ttlnetwgt = SUM(NetWgt) ,
               @n_ttlcount = SUM(Qty) FROM #OP_CARTONWORK
               SET ROWCOUNT 1
               SELECT @c_cartontype = CartonType
               FROM CARTONIZATION
               WHERE Cube >=@n_ttlcube AND
               MaxWeight >= @n_ttlgrosswgt AND
               MaxCount >= @n_ttlcount AND
               MaxWeight > 0 AND
               MaxCount > 0 AND
               Cube > 0 AND
               CartonizationGroup = @c_xcartongroup
               ORDER BY UseSequence DESC
               IF @@ROWCOUNT = 1
               BEGIN
                  SET ROWCOUNT 0
                  SELECT @b_success = 0
                  EXECUTE   nspg_getkey
                  "CartonID"
                  , 10
                  , @c_cartonid OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  IF @b_success = 1
                  BEGIN
                     INSERT #OP_CARTONLINESWORK
                     (Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,
                     loc,lot,id,caseid,cartontype, uom,uomqty,qty,packkey,cartongroup,stdcube, cube, StdGrossWgt,GrossWgt,
                     StdNetWgt, NetWgt,DoReplenish, replenishzone, docartonize,PickMethod )
                     (SELECT Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,
                     storerkey,sku,loc,lot,id,@c_cartonid,@c_cartontype,uom,uomqty,
                     qty,packkey,cartongroup,
                     stdcube,cube,StdGrossWgt,GrossWgt,
                     StdNetWgt,NetWgt,DoReplenish, replenishzone, docartonize,PickMethod
                     FROM #OP_CARTONWORK
                     )
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63604   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to insert into #OP_cartonlineswork. (nspcartonization)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     IF @n_continue = 1 or @n_continue = 2
                     BEGIN
                        DELETE FROM OP_CARTONLINES
                        WHERE Cartonbatch = @c_cartonbatch AND
                        orderkey = @c_xorderkey AND
                        Cartongroup = @c_xcartongroup AND
                        DoCartonize = 'Y'
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63602   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to delete frokm OP_cartonlines. (nspcartonization)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                     END
                     SELECT @b_cartonizationdone = 1
                  END
               END
            ELSE
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE   nspg_getkey
                  "CartonID"
                  , 10
                  , @c_cartonid OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  SELECT @b_boxfull = 0, @n_qtyalreadyinbox = 0 ,@n_grosswgtalreadyinbox = 0,
                  @n_netwgtalreadyinbox = 0, @n_cubealreadyinbox = 0
                  WHILE (1=1 and @b_success = 1 and @b_boxfull <> 1 and @b_cartonizationdone <> 1)
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_ypickdetailkey = pickdetailkey ,
                     @n_yuomqty = uomqty ,
                     @n_yqty = qty ,
                     @n_ystdgrosswgt = stdgrosswgt ,
                     @n_ystdnetwgt = stdnetwgt ,
                     @n_ystdcube = stdcube,
                     @n_ygrosswgt = grosswgt ,
                     @n_ynetwgt = netwgt ,
                     @n_ycube = cube ,
                     @c_ypickheaderkey = Pickheaderkey ,
                     @c_yorderlinenumber = orderlinenumber ,
                     @c_yuom  = uom ,
                     @c_yloc = loc ,
                     @c_ylot = lot ,
                     @c_ysku = sku ,
                     @c_ystorerkey = storerkey ,
                     @c_yid = id,
                     @c_ypackkey = packkey ,
                     @c_ydoreplenish = doreplenish ,
                     @c_yreplenishzone = replenishzone ,
                     @c_ydocartonize = docartonize          ,
                     @c_ypickmethod = pickmethod
                     FROM #OP_CARTONWORK
                     ORDER BY LOC
                     IF @@ROWCOUNT = 0
                     BEGIN
                        SELECT @b_cartonizationdone = 1
                        BREAK
                     END
                     SET ROWCOUNT 0
                     SELECT @c_yoriginaluom = @c_yuom
                     SELECT @c_yuom =
                     CASE @c_yuom
                     WHEN "6" THEN "6"
                     WHEN "7" THEN "7"
                  ELSE "6"
                  END
                  SELECT @n_loopcounter = 1
                  SELECT @n_qtytoputinbox = 1
                  WHILE @n_loopcounter <= @n_yqty
                  BEGIN
                     IF (@n_qtytoputinbox * @n_ystdgrosswgt) + @n_GrossWgtalreadyinbox > @n_bigboxweight
                     or (@n_qtytoputinbox * @n_ystdcube) + @n_cubealreadyinbox > @n_bigboxcube
                     or  (@n_qtytoputinbox) + @n_qtyalreadyinbox > @n_bigboxcount
                     BEGIN
                        SELECT @b_boxfull = 1
                        BREAK
                     END
                     SELECT @n_qtytoputinbox = @n_qtytoputinbox + 1
                     SELECT @n_loopcounter = @n_loopcounter + 1
                  END
                  IF @n_qtytoputinbox-1 > 0 and ( @n_continue =1 or @n_continue = 2)
                  BEGIN
                     SELECT @b_success = 0
                     EXECUTE   nspg_getkey
                     "PickDetailKey"
                     , 10
                     , @c_nextpickdetailkey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     IF @b_success = 1
                     BEGIN
                        SELECT @n_qtytoputinbox = @n_qtytoputinbox - 1
                        INSERT #OP_CARTONLINESWORK
                        (Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,
                        loc,lot,id,caseid,cartontype, uom,uomqty,qty,packkey,cartongroup,
                        stdcube, cube,
                        StdGrossWgt,GrossWgt,
                        StdNetWgt, NetWgt,
                        DoReplenish, replenishzone, docartonize,PickMethod )
                        VALUES
                        (@c_cartonbatch, @c_ypickheaderkey,@c_nextpickdetailkey ,@c_xorderkey, @c_yorderlinenumber ,@c_ystorerkey, @c_ysku,
                        @c_yloc, @c_ylot, @c_yid, @c_cartonid, @c_bigboxname,@c_yuom,@n_qtytoputinbox,@n_qtytoputinbox,@c_ypackkey,@c_xcartongroup,
                        @n_ystdcube, @n_qtytoputinbox * @n_ystdcube,
                        @n_ystdgrosswgt, @n_qtytoputinbox * @n_ystdgrosswgt ,
                        @n_ystdnetwgt, @n_qtytoputinbox * @n_ystdnetwgt ,
                        @c_ydoreplenish, @c_yreplenishzone, @c_ydocartonize,@c_ypickmethod )
                        SELECT @n_qtyalreadyinbox = @n_qtyalreadyinbox + @n_qtytoputinbox ,
                        @n_grosswgtalreadyinbox = @n_grosswgtalreadyinbox + (@n_qtytoputinbox * @n_ystdgrosswgt) ,
                        @n_netwgtalreadyinbox = @n_netwgtalreadyinbox + (@n_qtytoputinbox * @n_ystdnetwgt) ,
                        @n_cubealreadyinbox = @n_cubealreadyinbox + (@n_qtytoputinbox * @n_ystdcube)
                        IF @n_qtyalreadyinbox >= @n_bigboxcount or @n_grosswgtalreadyinbox >= @n_bigboxweight
                        or @n_cubealreadyinbox >=@n_bigboxcube
                        BEGIN
                           SELECT @b_boxfull = 1
                        END
                        IF @n_yqty = @n_qtytoputinbox
                        BEGIN
                           DELETE FROM OP_CARTONLINES
                           WHERE Cartonbatch = @c_cartonbatch AND
                           orderkey = @c_xorderkey AND
                           Cartongroup = @c_xcartongroup AND
                           PickDetailKey = @c_ypickdetailkey
                           DELETE FROM #OP_CARTONWORK
                           WHERE Cartonbatch = @c_cartonbatch AND
                           orderkey = @c_xorderkey AND
                           Cartongroup = @c_xcartongroup AND
                           PickDetailKey = @c_ypickdetailkey
                        END
                     ELSE
                        BEGIN
                           SELECT @n_yNewUomQty =
                           CASE @c_yoriginaluom
                           WHEN "6" THEN
                           (SELECT UOMQTY - @n_qtytoputinbox FROM OP_CARTONLINES
                           WHERE Cartonbatch = @c_cartonbatch AND
                           orderkey = @c_xorderkey AND
                           Cartongroup = @c_xcartongroup AND
                           PickDetailKey = @c_ypickdetailkey)
                           WHEN "7" THEN
                           (SELECT UOMQTY - @n_qtytoputinbox FROM OP_CARTONLINES
                           WHERE Cartonbatch = @c_cartonbatch AND
                           orderkey = @c_xorderkey AND
                           Cartongroup = @c_xcartongroup AND
                           PickDetailKey = @c_ypickdetailkey)
                        ELSE
                           (SELECT QTY - @n_qtytoputinbox FROM OP_CARTONLINES
                           WHERE Cartonbatch = @c_cartonbatch AND
                           orderkey = @c_xorderkey AND
                           Cartongroup = @c_xcartongroup AND
                           PickDetailKey = @c_ypickdetailkey)
                        END
                        SELECT @c_yuom =
                        CASE @c_yuom
                        WHEN "6" THEN "6"
                        WHEN "7" THEN "7"
                     ELSE "7"
                     END
                     UPDATE OP_CARTONLINES
                     SET UOMQty = @n_yNewUomQty ,
                     UOM = @c_yuom ,
                     Qty = Qty - @n_qtytoputinbox
                     WHERE Cartonbatch = @c_cartonbatch AND
                     orderkey = @c_xorderkey AND
                     Cartongroup = @c_xcartongroup AND
                     PickDetailKey = @c_ypickdetailkey
                     UPDATE #OP_CARTONWORK
                     SET UOMQty = @n_yNewUomQty ,
                     UOM = @c_yuom ,
                     Qty = Qty - @n_qtytoputinbox ,
                     Cube = Cube - (@n_qtytoputinbox * @n_ystdcube) ,
                     GrossWgt = GrossWgt - (@n_qtytoputinbox * @n_ystdgrosswgt) ,
                     NetWgt = NetWgt - (@n_qtytoputinbox * @n_ystdnetwgt)
                     WHERE Cartonbatch = @c_cartonbatch AND
                     orderkey = @c_xorderkey AND
                     Cartongroup = @c_xcartongroup AND
                     PickDetailKey = @c_ypickdetailkey
                  END -- @n_yqty = @n_qtytoputinbox
               END -- If @b_success = 1
            END -- @n_qtytoputinbox-1 > 0 and ( @n_continue =1 or @n_continue = 2)
         END -- (1=1 and @b_success = 1 and @b_boxfull <> 1 and @b_cartonizationdone <> 1)
         SET ROWCOUNT 0
      END  -- IF @@ROWCOUNT = 1
      SET ROWCOUNT 0
   END -- WHILE @n_continue = 1 or @n_continue = 2 and @b_cartonizationdone = 0
   IF @b_debug = 1
   BEGIN
      PRINT "OP_CARTONLINES"
      SELECT * FROM OP_CARTONLINES
      PRINT "#OP_CARTONWORK"
      SELECT * FROM #OP_CARTONWORK
      PRINT "#OP_CARTONLINESWORK"
      SELECT * FROM #OP_CARTONLINESWORK
   END
END
END -- WHILE (1=1)
IF @n_continue = 1 or @n_continue = 2
BEGIN
   SET ROWCOUNT 1
   WHILE (1=1)
   BEGIN
      SELECT @c_pickdetailkey  = PickDetailKey
      FROM OP_CARTONLINES
      WHERE Cartonbatch = @c_cartonbatch AND
      CaseID = ""
      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END
      SELECT @b_success = 0
      EXECUTE   nspg_getkey
      "CartonID"
      , 10
      , @c_cartonid OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      IF @b_success = 1
      BEGIN
         UPDATE OP_CARTONLINES SET Caseid = @c_cartonid
         WHERE PickDetailkey = @c_pickdetailkey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63605   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to update OP_cartonlines. (nspcartonization)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   SET ROWCOUNT 0
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   SELECT @n_continue = 1
   INSERT OP_CARTONLINES
   ( Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,
   loc,lot,id,caseid,uom,uomqty,qty,packkey,cartongroup,cartontype,DoReplenish, replenishzone, docartonize,pickmethod )
   ( SELECT cartonbatch,pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,
   loc,lot,id,caseid,uom,uomqty,qty,packkey,cartongroup,cartontype,DoReplenish, replenishzone, docartonize,pickmethod
   FROM #OP_CARTONLINESWORK )
END
CLOSE CURSOR_PARTIALS_GROUP
DEALLOCATE CURSOR_PARTIALS_GROUP
IF @b_debug = 1
BEGIN
   PRINT ""
   PRINT "OP_CARTONLINES Table After Cartonization"
   SELECT * FROM OP_CARTONLINES
END
END
/* #INCLUDE <SPC2.SQL> */
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
   execute nsp_logerror @n_err, @c_errmsg, "nspCartonization"
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
END


GO