SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_ShippingManifest_By_Store_HK_Det                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* SOS32749		June				Bug fixed double figure of QtyShipped		*/
/*										if one sku appear > 1 in PODETAIL			*/
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_ShippingManifest_By_Store_HK_Det] 
@c_LoadKey1  NVARCHAR(10) = '' ,
@c_LoadKey2  NVARCHAR(10) = '' ,
@c_LoadKey3  NVARCHAR(10) = '' ,
@c_LoadKey4  NVARCHAR(10) = '' ,
@c_LoadKey5  NVARCHAR(10) = '' ,
@c_LoadKey6  NVARCHAR(10) = '' ,
@c_LoadKey7  NVARCHAR(10) = '' ,
@c_LoadKey8  NVARCHAR(10) = '' ,
@c_LoadKey9  NVARCHAR(10) = '' ,
@c_LoadKey10 NVARCHAR(10) = '' ,
@c_Store     NVARCHAR(15) = '' 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_SQL NVARCHAR(max)

	-- Start : 32749, move it here, USe @c_SQL2
	DECLARE @c_SQL2 NVARCHAR(3000)
	SELECT @c_SQL2 = ''
   IF dbo.fnc_RTrim(@c_LoadKey1) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey1) <> '' 
   BEGIN
      IF (dbo.fnc_RTrim(@c_LoadKey2) IS NULL OR dbo.fnc_RTrim(@c_LoadKey2) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey3) IS NULL OR dbo.fnc_RTrim(@c_LoadKey3) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey4) IS NULL OR dbo.fnc_RTrim(@c_LoadKey4) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey5) IS NULL OR dbo.fnc_RTrim(@c_LoadKey5) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey6) IS NULL OR dbo.fnc_RTrim(@c_LoadKey6) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey7) IS NULL OR dbo.fnc_RTrim(@c_LoadKey7) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey8) IS NULL OR dbo.fnc_RTrim(@c_LoadKey8) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey9) IS NULL OR dbo.fnc_RTrim(@c_LoadKey9) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey10) IS NULL OR dbo.fnc_RTrim(@c_LoadKey10) = '' ) 
      BEGIN
         SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + " AND LP.LoadKey = N'" + dbo.fnc_RTrim(@c_LoadKey1) + "' "
      END 
      ELSE
      BEGIN
         SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + " AND LP.LoadKey IN (N'" + dbo.fnc_RTrim(@c_LoadKey1) + "'"

         IF (dbo.fnc_RTrim(@c_LoadKey2) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey2) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey2) + "'"
         END 

         IF (dbo.fnc_RTrim(@c_LoadKey3) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey3) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey3) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey4) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey4) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey4) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey5) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey5) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey5) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey6) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey6) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey6) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey7) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey7) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey7) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey8) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey8) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey8) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey9) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey9) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey9) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey10) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey10) <> '' ) 
         BEGIN
            SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ", N'" + dbo.fnc_RTrim(@c_LoadKey10) + "'"
         END 
         SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + ") "
      END
   END 
	-- End : 32749

   SELECT @c_SQL = 
      " SELECT " +
      " DISTINCT  " +
      " ORDERS.ConsigneeKey,  " +
      " ORDERS.C_Company,  " +
      " ORDERS.C_Address1,  " +
      " ORDERS.C_Address2,  " +
      " ORDERS.C_Address3,  " +
      " ORDERS.ExternOrderKey,  " +
      " CASE ORDERS.Type WHEN 'ALLOCATION' THEN '(NA)'  " +
      " 			   WHEN 'XDOCK' THEN '(XD)'  " +
      " 				ELSE ''  " +
      " END as Type, " +
      " ORDERS.LoadKey,  " +
      " SKU.Sku,  " +
      " CASE ORDERDETAIL.Userdefine03 WHEN 'ALLOCATION' THEN '(BA)'    " +
      " 						   WHEN 'STOREORDER' THEN '(StO)'    " +
      " 							ELSE ORDERDETAIL.Userdefine03    " +
      " END as Source,   " +
      " SKU.DESCR,  " +
      " SUM ( ORDERDETAIL.OriginalQty ) as QtyOrdered,  " +
      " SUM ( ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty ) as QtyShipped,  " +
      " ORIGIN.Company as Origination,    " +
      " SKU.Price,   " +
      " SKU.BUSR5 as DivisionCd,   " +
      -- Start : Add by June 10.Nov.2004 (SOS27707)
--    " (CASE WHEN MAX(PODETAIL.QtyOrdered) - MAX(PODETAIL.QtyReceived) > 0 THEN 'SS'  " +
--    "       WHEN MAX(PODETAIL.QtyOrdered) = 0 THEN '0qty' ELSE '  ' END) " +
      " (CASE WHEN SUM ( ORDERDETAIL.OriginalQty ) - SUM ( ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty ) = 0 THEN ' '  " +
	   " 		  WHEN MAX(PODETAIL.QtyOrdered) - MAX(PODETAIL.QtyReceived) > 0 THEN 'SS'  " +
      "       WHEN MAX(PODETAIL.QtyOrdered) = 0 THEN '0qty' ELSE '  ' END) " +
      -- End : Add by June 10.Nov.2004 (SOS27707)
		-- Start : 32749
      -- " FROM ORDERS (NOLOCK), SKU (NOLOCK), ORDERDETAIL (NOLOCK) " +
      -- " LEFT OUTER JOIN PODETAIL (NOLOCK) ON (PODETAIL.ExternPOKey=ORDERDETAIL.ExternPOKey AND  " +
      -- "                              PODETAIL.StorerKey=ORDERDETAIL.StorerKey AND  " +
      -- "                              PODETAIL.Sku=ORDERDETAIL.Sku)  " +
		" FROM ORDERS (NOLOCK) " +
		" INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey) " +
		" INNER JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.SKU = SKU.SKU) " +
		" INNER JOIN LOADPLANDETAIL LP (NOLOCK) ON (LP.Orderkey = ORDERS.Orderkey) " +
		" LEFT OUTER JOIN (SELECT QtyOrdered = SUM(P.QtyOrdered), QtyReceived = SUM(P.QtyReceived), " +
		"								  P.ExternPOkey, P.Storerkey, P.SKU " + 
		"						FROM PODETAIL P (NOLOCK) " +
		" 						JOIN ORDERS (NOLOCK) ON ORDERS.ExternPokey = P.ExternPOkey AND P.Storerkey = ORDERS.Storerkey " + 
		"						JOIN LOADPLANDETAIL LP (NOLOCK) ON LP.Orderkey = ORDERS.Orderkey " + 
		"						WHERE (ORDERS.StorerKey = '11315') " + @c_SQL2 + 
		" 						GROUP BY P.ExternPOkey, P.Storerkey, P.SKU) AS PODETAIL  " +
		"							ON (PODETAIL.ExternPOKey=ORDERDETAIL.ExternPOKey " +
		"								 AND PODETAIL.StorerKey=ORDERDETAIL.StorerKey " +
		"							 	 AND PODETAIL.Sku=ORDERDETAIL.Sku) " +
		-- End : 32749
      " LEFT OUTER JOIN STORER ORIGIN (NOLOCK) ON (ORIGIN.StorerKey = 'IDS') " +
      -- Start : 32749
      -- " WHERE (ORDERDETAIL.OrderKey = ORDERS.OrderKey AND  " +
      -- "        ORDERDETAIL.Sku = SKU.Sku AND  " +
      -- "        ORDERDETAIL.StorerKey=SKU.StorerKey) " +
      -- " AND   (ORDERS.StorerKey = '11315') " 
      -- End  : 32749
      " WHERE (ORDERS.StorerKey = '11315') " 
	-- Start : 32749, move it up
	/*
   IF dbo.fnc_RTrim(@c_LoadKey1) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey1) <> '' 
   BEGIN
      IF (dbo.fnc_RTrim(@c_LoadKey2) IS NULL OR dbo.fnc_RTrim(@c_LoadKey2) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey3) IS NULL OR dbo.fnc_RTrim(@c_LoadKey3) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey4) IS NULL OR dbo.fnc_RTrim(@c_LoadKey4) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey5) IS NULL OR dbo.fnc_RTrim(@c_LoadKey5) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey6) IS NULL OR dbo.fnc_RTrim(@c_LoadKey6) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey7) IS NULL OR dbo.fnc_RTrim(@c_LoadKey7) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey8) IS NULL OR dbo.fnc_RTrim(@c_LoadKey8) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey9) IS NULL OR dbo.fnc_RTrim(@c_LoadKey9) = '' ) AND
         (dbo.fnc_RTrim(@c_LoadKey10) IS NULL OR dbo.fnc_RTrim(@c_LoadKey10) = '' ) 
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " AND ORDERS.LoadKey = N'" + dbo.fnc_RTrim(@c_LoadKey1) + "' "
      END 
      ELSE
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " AND ORDERS.LoadKey IN (N'" + dbo.fnc_RTrim(@c_LoadKey1) + "'"

         IF (dbo.fnc_RTrim(@c_LoadKey2) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey2) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey2) + "'"
         END 

         IF (dbo.fnc_RTrim(@c_LoadKey3) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey3) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey3) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey4) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey4) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey4) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey5) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey5) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey5) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey6) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey6) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey6) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey7) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey7) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey7) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey8) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey8) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey8) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey9) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey9) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey9) + "'"
         END 
         IF (dbo.fnc_RTrim(@c_LoadKey10) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey10) <> '' ) 
         BEGIN
            SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ", N'" + dbo.fnc_RTrim(@c_LoadKey10) + "'"
         END 
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ") "
      END

      IF (dbo.fnc_RTrim(@c_Store) IS NOT NULL AND dbo.fnc_RTrim(@c_Store) <> '' )
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " AND ORDERS.Consigneekey = N'" + dbo.fnc_RTrim(@c_Store) + "'"
      END 
   END 
   ELSE
   BEGIN
      IF (dbo.fnc_RTrim(@c_Store) IS NOT NULL AND dbo.fnc_RTrim(@c_Store) <> '' )
      BEGIN
         SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " AND ORDERS.Consigneekey = N'" + dbo.fnc_RTrim(@c_Store) + "'"
      END  
	END

   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + " GROUP BY ORDERS.ConsigneeKey, ORDERS.C_Company, ORDERS.C_Address1, " + 
      "ORDERS.C_Address2, ORDERS.C_Address3, ORDERS.C_Address4, SKU.BUSR5, SKU.Sku, SKU.DESCR,  " + 
      "SKU.Price, ORDERDETAIL.UserDefine03, ORDERS.ExternOrderKey, " + 
      "CASE ORDERS.Type WHEN 'ALLOCATION' THEN '(NA)' WHEN 'XDOCK' THEN '(XD)' ELSE '' END, ORDERS.LoadKey,  " + 
      "CASE WHEN ORDERDETAIL.UserDefine03 = 'ALLOCATION' THEN 'BA' WHEN ORDERDETAIL.UserDefine03 = 'STOREORDER'  " + 
      "THEN 'StO' ELSE '  ' END, ORIGIN.Company   "  
	*/
   IF (dbo.fnc_RTrim(@c_Store) IS NOT NULL AND dbo.fnc_RTrim(@c_Store) <> '' )
   BEGIN
      SELECT @c_SQL2 = dbo.fnc_RTrim(@c_SQL2) + " AND ORDERS.Consigneekey = N'" + dbo.fnc_RTrim(@c_Store) + "'"
   END 

   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + dbo.fnc_RTrim(@c_SQL2) + " GROUP BY ORDERS.ConsigneeKey, ORDERS.C_Company, ORDERS.C_Address1, " + 
      "ORDERS.C_Address2, ORDERS.C_Address3, ORDERS.C_Address4, SKU.BUSR5, SKU.Sku, SKU.DESCR,  " + 
      "SKU.Price, ORDERDETAIL.UserDefine03, ORDERS.ExternOrderKey, " + 
      "CASE ORDERS.Type WHEN 'ALLOCATION' THEN '(NA)' WHEN 'XDOCK' THEN '(XD)' ELSE '' END, ORDERS.LoadKey,  " + 
      "CASE WHEN ORDERDETAIL.UserDefine03 = 'ALLOCATION' THEN 'BA' WHEN ORDERDETAIL.UserDefine03 = 'STOREORDER'  " + 
      "THEN 'StO' ELSE '  ' END, ORIGIN.Company   "  
	-- End : 32749

   -- print @c_SQL 
   EXEC( @c_SQL) 
END 

GO