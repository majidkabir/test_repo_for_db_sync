SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_checking_report                                        */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 07-Jul-2012            1.0   Initial revision                           */
/* 21-Mar-2014  tlting    1.1   SQL2012 Bug fix                            */
/***************************************************************************/    
CREATE PROC [dbo].[isp_checking_report] @c_xdockpokey nvarchar(8)
AS
BEGIN -- main
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- create result table
   BEGIN TRANSACTION
      CREATE TABLE #result (
         pickslipno nvarchar(10) NULL,
         xdockpokey nvarchar(8) NULL,
         sellersreference nvarchar(18) NULL,
         sellername nvarchar(45) NULL,
         storerkey nvarchar(15) NULL,
         sku nvarchar(20) NULL,
         descr nvarchar(60) NULL,
         orderkey nvarchar(10) NULL,
         consigneekey nvarchar(10) NULL,
         company nvarchar(45) NULL,
         totalqty int NULL,
         casecnt float(53) NULL,
         reprint nvarchar(1) NULL
      )
   COMMIT

   DECLARE @c_orderkey nvarchar(10),
           @c_pickslipno nvarchar(10),
           @c_reprint nvarchar(1),
           @b_success int,
           @n_err int,
           @c_errmsg nvarchar(255)

   SELECT
      @c_orderkey = ''
   WHILE (1 = 1)
   BEGIN -- while 1
      SELECT
         @c_orderkey = MIN(orderkey)
      FROM orders(nolock)
      WHERE pokey = @c_xdockpokey
      AND orderkey > @c_orderkey

      IF @@rowcount = 0
         OR @c_orderkey IS NULL
         OR @c_orderkey = NULL
         BREAK

      IF NOT EXISTS (SELECT
            1
         FROM pickheader(nolock)
         WHERE orderkey = @c_orderkey)
      BEGIN
         SELECT
            @b_success = 0
         EXECUTE nspg_GetKey 'PICKSLIP',
                             9,
                             @c_pickslipno OUTPUT,
                             @b_success OUTPUT,
                             @n_err OUTPUT,
                             @c_errmsg OUTPUT

         IF @b_success = 1
         BEGIN
            SELECT
               @c_pickslipno = 'P' + @c_pickslipno
            BEGIN TRAN
               INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, PickType, Zone, TrafficCop)
                  VALUES (@c_pickslipno, @c_orderkey, '0', '3', '')
               SELECT
                  @n_err = @@error
               IF @n_err = 0
               COMMIT TRAN
            ELSE
            BEGIN
               SELECT
                  @c_errmsg = 'Pickheader Insert Failed. (isp_checking_report).'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               ROLLBACK TRAN
            END
         END
         ELSE
         BEGIN
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            RETURN
         END
      END
      ELSE -- pickslip already existing
      BEGIN
         SELECT
            @c_pickslipno = pickheaderkey,
            @c_reprint = 'Y'
         FROM pickheader(nolock)
         WHERE orderkey = @c_orderkey
      END

      -- insert into #result
      INSERT #result
         SELECT
            @c_pickslipno,
            po.xdockpokey,
            po.sellersreference,
            po.sellername,
            orderdetail.storerkey,
            orderdetail.sku,
            sku.descr,
            orderdetail.orderkey,
            consigneekey = dbo.fnc_RTrim(SUBSTRING(orders.consigneekey, 5, 10)),
            orders.c_company,
            totalqty = SUM(orderdetail.qtyallocated + qtypicked + shippedqty),
            CONVERT(int, pack.casecnt),
            @c_reprint
         FROM po(nolock)
         JOIN orders(nolock)
            ON po.xdockpokey = orders.pokey
         JOIN orderdetail(nolock)
            ON orders.orderkey = orderdetail.orderkey
         JOIN sku(nolock)
            ON sku.storerkey = orderdetail.storerkey
            AND sku.sku = orderdetail.sku
         JOIN pack(nolock)
            ON sku.packkey = pack.packkey
         WHERE orders.orderkey = @c_orderkey
         AND po.xdockpokey = @c_xdockpokey
         GROUP BY po.xdockpokey,
                  po.sellersreference,
                  po.sellername,
                  orderdetail.storerkey,
                  orderdetail.sku,
                  sku.descr,
                  orderdetail.orderkey,
                  orders.consigneekey,
                  orders.c_company,
                  pack.casecnt
         HAVING SUM(orderdetail.qtyallocated + qtypicked + shippedqty) > 0
   END -- while 1

   -- display result
   SELECT
      *
   FROM #result

   BEGIN TRAN
      DROP TABLE #result
   COMMIT TRAN
END -- main

GO