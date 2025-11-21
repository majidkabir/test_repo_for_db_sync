SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrdersByVehicle                                 */
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

CREATE PROC [dbo].[nspOrdersByVehicle] (
@c_storerkey	 NVARCHAR(18),
@c_vessel_start NVARCHAR(30),
@c_vessel_end	 NVARCHAR(30),
@d_date_start		datetime,
@d_date_end			datetime
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_vessel	 NVARCHAR(30),
   @c_externorderkey NVARCHAR(20),
   @c_deliverydate NVARCHAR(10),
   @c_reason		 NVARCHAR(10),
   @n_rejects			int
   -- create a temp result table
   SELECT company,
   ORDERS.externorderkey,
   vessel,
   totalorders = COUNT(DISTINCT MBOLDETAIL.orderkey),
   deliverydate = CONVERT(char(10), MBOLDETAIL.Deliverydate, 101),
   Damage = 0,
   None = 0,
   Noodr = 0,
   Others = 0,
   Ovrstk = 0,
   Wrgadr = 0,
   WrgItm = 0,
   datestart = CONVERT(char(10), @d_date_start, 101),
   dateend= CONVERT(char(10), @d_date_end, 101)
   INTO #RESULT
   FROM MBOL (NOLOCK),
   MBOLDETAIL (NOLOCK),
   ORDERS (NOLOCK),
   STORER (NOLOCK)
   WHERE MBOL.MbolKey = MBOLDETAIL.MbolKey AND
   MBOLDETAIL.OrderKey = ORDERS.OrderKey AND
   ORDERS.StorerKey = STORER.StorerKey AND
   ORDERS.StorerKey = @c_storerkey AND
   MBOL.Vessel BETWEEN @c_vessel_start AND @c_vessel_end AND
   MBOLDETAIL.DeliveryDate BETWEEN @d_date_start AND @d_date_end
   GROUP BY company,
   ORDERS.externorderkey,
   MBOL.Vessel,
   CONVERT(char(10), MBOLDETAIL.Deliverydate, 101)
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT MBOL.Vessel,
   ORDERS.ExternOrderKey,
   deliverydate = CONVERT(char(10), MBOLDETAIL.Deliverydate, 101)
   FROM MBOL (NOLOCK),
   MBOLDETAIL (NOLOCK),
   ORDERS (NOLOCK),
   STORER (NOLOCK)
   WHERE MBOL.MbolKey = MBOLDETAIL.MbolKey AND
   MBOLDETAIL.OrderKey = ORDERS.OrderKey AND
   ORDERS.StorerKey = STORER.StorerKey AND
   ORDERS.StorerKey = @c_storerkey AND
   MBOL.Vessel BETWEEN @c_vessel_start AND @c_vessel_end AND
   MBOLDETAIL.DeliveryDate BETWEEN @d_date_start AND @d_date_end
   GROUP BY MBOL.Vessel,
   ORDERS.ExternOrderKey,
   CONVERT(char(10), MBOLDETAIL.Deliverydate, 101)
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_vessel, @c_externorderkey, @c_deliverydate
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @n_rejects = COUNT(*), @c_reason = asnreason
      FROM RECEIPT (NOLOCK)
      WHERE carrierreference = @c_externorderkey
      GROUP BY asnreason
      IF @@ROWCOUNT <> 0
      BEGIN
         -- count reject of no orders
         IF @c_reason = 'NOODR'
         UPDATE #RESULT
         SET noodr = noodr + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
         -- count reject of damage
         IF @c_reason = 'DAMAGE'
         UPDATE #RESULT
         SET damage = damage + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
         -- count reject of none
         IF @c_reason = 'NONE'
         UPDATE #RESULT
         SET none = none + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
         -- count reject of others
         IF @c_reason = 'OTHERS'
         UPDATE #RESULT
         SET others = others + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
         -- count reject of over stock
         IF @c_reason = 'OVRSTK'
         UPDATE #RESULT
         SET ovrstk = ovrstk + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
         -- count reject of wrong address
         IF @c_reason = 'WRGADR'
         UPDATE #RESULT
         SET wrgadr = wrgadr + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
         IF @c_reason = 'WRGITM'
         UPDATE #RESULT
         SET wrgitm = wrgitm + 1
         WHERE vessel = @c_vessel
         AND deliverydate = @c_deliverydate
         AND externorderkey = @c_externorderkey
      END
      FETCH NEXT FROM cur_1 INTO @c_vessel, @c_externorderkey, @c_deliverydate
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   SELECT company,
   vessel,
   totalorders = sum(totalorders),
   deliverydate,
   Damage = sum(damage),
   None = sum(none),
   Noodr = sum(noodr),
   Others = sum(others),
   Ovrstk = sum(ovrstk),
   Wrgadr = sum(wrgadr),
   WrgItm = sum(wrgitm),
   datestart,
   dateend
   FROM #RESULT
   GROUP BY company,
   vessel,
   deliverydate,
   datestart,
   dateend
   DROP TABLE #RESULT
END

GO