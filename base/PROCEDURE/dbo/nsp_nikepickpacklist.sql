SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store Procedure: nsp_NikePickPackList                                */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Generate PickPack List                                      */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* June-2003    DLIM       Initial Creation for - Nike Pick Pack List   */  
/*                         - (FBR#10990).                               */  
/* Sept-2003    JEFF       Modified the select statement. No SOS.       */  
/* 22-Aug-2003  YokeBeen   - (SOS#10992) - (YokeBeen01).                */  
/* 10-Jun-2005  ONG        - NSC Project Change Request - (SOS#34681).  */   
/* 11-Jul-2005  YokeBeen   Changed ORDERS.BuyerPO to ORDERS.ExternPOKey */  
/*                         - (SOS#34681) - (YokeBeen02).                */  
/* 11-Jun-2014  NJOW01     -315696 - Fix duplicate size                 */  
/* 23-Jun-2015  CSCHONG    -344737 - Change sorting  (CS01)             */  
/* 17-Mar-2016  CSCHONG    -366296 - Change Sorting  (CS02)             */  
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */   																			 
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_NikePickPackList] (@c_wavekey_start NVARCHAR(10), @c_wavekey_end NVARCHAR(10),   
                                  @c_storerkey_start NVARCHAR(10), @c_storerkey_end NVARCHAR(10),   
                                  --@c_externorderkey_start NVARCHAR(10), @c_externorderkey_end NVARCHAR(10),   
								  @c_externorderkey_start NVARCHAR(50), @c_externorderkey_end NVARCHAR(50),    --tlting_ext  
								  @c_invoiceno_start NVARCHAR(10), @c_invoiceno_end NVARCHAR(10))  
  
AS  
  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE @c_size NVARCHAR(5),  
   @c_qty NVARCHAR(5),  
   @b_success int,  
   @n_err int,  
   @n_continue int,  
   @n_starttcnt int,  
   @c_errmsg NVARCHAR(255),  
   @c_loopcnt int,  
   @theSQLStmt NVARCHAR(255),   
   @c_sku NVARCHAR(50),  
   --@c_externorderkey NVARCHAR(30),  
   @c_externorderkey NVARCHAR(50),     --tlting_ext  
   @c_ReprintFlag NVARCHAR(1),  -- (YokeBeen01)   
      @c_BUSR6 NVARCHAR(30),   -- Ong sos34681 10Jun2005  
      @c_BUSR7 NVARCHAR(30),  --NJOW01  
      @c_Lottable02 NVARCHAR(18) --NJOW01  
                  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @theSQLStmt = ''  
  
 -- (YokeBeen01) - Start  
 IF (@c_wavekey_start <> @c_wavekey_end)  
 BEGIN  
  SELECT @c_ReprintFlag = '*'   
 END  
 ELSE   
 BEGIN  
  SELECT @c_ReprintFlag = ' '   
 END  
 -- (YokeBeen01) - End  
  
   SELECT    
          ISNULL (max(o.b_company), ' ' ) b_company,    
          ISNULL (max(o.b_address1), ' ' ) b_address1,   
          ISNULL (max(o.b_address2), ' ' ) b_address2,    
          ISNULL (max(o.b_address3), ' ' ) b_address3,   
          ISNULL (max(o.b_address4), ' ' ) b_address4,   
          ISNULL (max(o.b_country), ' ')  b_country,   
          ISNULL (max(o.c_company), ' ')  c_company,   
          ISNULL (max(o.c_address1), ' ' )c_address1,   
          ISNULL (max(o.c_address2), ' ') c_address2,   
          ISNULL (max(o.c_address3), ' ') c_address3,   
          ISNULL (max(o.c_address4), ' ' ) c_address4,   
          ISNULL (max(o.c_city), ' ' ) c_City, -- added by Ong sos34681  050503  
          ISNULL (max(o.c_country), ' ' ) c_country,   
          max(o.externorderkey) ExternOrderKey,   
--           max(o.buyerpo) BuyerPO, -- (YokeBeen02)  
          max(o.ExternPOKey) ExternPOKey,   -- (YokeBeen02)  
          max(convert(char(10),o.orderdate,6)) OrderDate,   
          max(o.invoiceno) InvoiceNo,   
          max(o.userdefine02) UDef02,   
          substring(OD.sku,1,9) SKU,  -- modified by Ong sos34681 050607  
          max(s.descr) Descr,   
          SUM(od.Originalqty)  OrderedQty,   
          SUM(P.QTY) PDQTY  
         ,max(cast(o.notes as NVARCHAR(120))) Remarks,   
    @c_ReprintFlag ReprintFlag  -- (YokeBeen01)             
         , LEFT(ISNULL(S.BUSR7,''),2) BUSR7   -- added by Ong sos 34681   050607  
         , pack.packuom3   -- added by Ong sos 34681   050607  
         , LA.lottable02   -- added by Ong sos 34681   050613  
         , S.Price UnitPrice -- added by Ong sos 34681   050615  
         , St.LabelPrice   -- added by Ong sos 34681   050615  
         ,max(convert(char(10),o.deliverydate,6)) DeliveryDate  -- added by Ong sos 34681   050627  
         , isnull(o.route,'') ord_route,isnull(o.consigneekey,'') ord_consigneekey        --(CS01)  
   INTO #TempNPPL  
   FROM PICKDETAIL P (NOLOCK)   
      JOIN orders o(NOLOCK) on (P.OrderKey = o.OrderKey)   
      JOIN ORdERDETAIL OD (NOLOCK) ON (O.orderkey = OD.Orderkey  
                  AND P.Orderlinenumber = OD.Orderlinenumber  
                  AND P.Orderkey = OD.Orderkey)   
      JOIN WAVEDETAIL WD (NOLOCK) ON (O.Orderkey = WD.Orderkey)  
      JOIN SKU S (NOLOCK) ON (OD.SKU = S.SKU AND OD.Storerkey = S.Storerkey )  
      JOIN Pack (NOLOCK) ON (Pack.packkey = s.packkey)         -- added by Ong 3/5/05  
--      JOIN LotAttribute LA (NOLOCK) ON (OD.SKU = LA.SKU AND OD.Storerkey = LA.Storerkey )  
      JOIN LotAttribute LA (NOLOCK) ON (P.Lot = LA.Lot) -- added by Ong sos 34681   050613  
      LEFT JOIN Storer St (NOLOCK) ON (O.ConsigneeKey = St.Storerkey )  
   WHERE   wd.wavekey >= @c_wavekey_start AND wd.wavekey <= @c_wavekey_end     
   AND o.storerkey >= @c_storerkey_start AND o.storerkey <= @c_storerkey_end   
   AND o.externorderkey >= @c_externorderkey_start AND o.externorderkey <= @c_externorderkey_end   
   AND o.invoiceno >= @c_invoiceno_start AND o.invoiceno <= @c_invoiceno_end   
   GROUP BY o.externorderkey , substring(OD.sku,1,9),  -- modified by Ong sos34681 7/6/05   
           LEFT(ISNULL(S.BUSR7,''),2), pack.packuom3, LA.lottable02, s.price,St.LabelPrice   -- od.unitprice,  added by Ong sos 34681  
           ,isnull(o.route,''),isnull(o.consigneekey,'')        --(CS01)  
   ORDER BY o.externorderkey , substring(OD.sku,1,9), LA.lottable02  --, P.SKU, s.busr7,   
  
     
  
   ALTER TABLE #TempNPPL ADD   
                  SizeCOL1 NVARCHAR(5) NULL, QtyCOL1 NVARCHAR(5) NULL,  
                  SizeCOL2 NVARCHAR(5) NULL, QtyCOL2 NVARCHAR(5) NULL,  
                  SizeCOL3 NVARCHAR(5) NULL, QtyCOL3 NVARCHAR(5) NULL,  
                  SizeCOL4 NVARCHAR(5) NULL, QtyCOL4 NVARCHAR(5) NULL,  
                  SizeCOL5 NVARCHAR(5) NULL, QtyCOL5 NVARCHAR(5) NULL,  
                  SizeCOL6 NVARCHAR(5) NULL, QtyCOL6 NVARCHAR(5) NULL,  
               SizeCOL7 NVARCHAR(5) NULL, QtyCOL7 NVARCHAR(5) NULL,  
                  SizeCOL8 NVARCHAR(5) NULL, QtyCOL8 NVARCHAR(5) NULL,  
                  SizeCOL9 NVARCHAR(5) NULL, QtyCOL9 NVARCHAR(5) NULL,  
                  SizeCOL10 NVARCHAR(5) NULL, QtyCOL10 NVARCHAR(5) NULL,  
                  SizeCOL11 NVARCHAR(5) NULL, QtyCOL11 NVARCHAR(5) NULL,  
                  SizeCOL12 NVARCHAR(5) NULL, QtyCOL12 NVARCHAR(5) NULL,  
                  SizeCOL13 NVARCHAR(5) NULL, QtyCOL13 NVARCHAR(5) NULL,  
                  SizeCOL14 NVARCHAR(5) NULL, QtyCOL14 NVARCHAR(5) NULL,  
                  SizeCOL15 NVARCHAR(5) NULL, QtyCOL15 NVARCHAR(5) NULL,  
                  SizeCOL16 NVARCHAR(5) NULL, QtyCOL16 NVARCHAR(5) NULL,  
                  SizeCOL17 NVARCHAR(5) NULL, QtyCOL17 NVARCHAR(5) NULL,  
                  SizeCOL18 NVARCHAR(5) NULL, QtyCOL18 NVARCHAR(5) NULL,  
                  SizeCOL19 NVARCHAR(5) NULL, QtyCOL19 NVARCHAR(5) NULL,  
                  SizeCOL20 NVARCHAR(5) NULL, QtyCOL20 NVARCHAR(5) NULL,  
                  SizeCOL21 NVARCHAR(5) NULL, QtyCOL21 NVARCHAR(5) NULL,  
                  SizeCOL22 NVARCHAR(5) NULL, QtyCOL22 NVARCHAR(5) NULL,  
                  SizeCOL23 NVARCHAR(5) NULL, QtyCOL23 NVARCHAR(5) NULL,  
                  SizeCOL24 NVARCHAR(5) NULL, QtyCOL24 NVARCHAR(5) NULL,  
                  SizeCOL25 NVARCHAR(5) NULL, QtyCOL25 NVARCHAR(5) NULL,  
                  SizeCOL26 NVARCHAR(5) NULL, QtyCOL26 NVARCHAR(5) NULL,  
                  SizeCOL27 NVARCHAR(5) NULL, QtyCOL27 NVARCHAR(5) NULL,  
                  SizeCOL28 NVARCHAR(5) NULL, QtyCOL28 NVARCHAR(5) NULL,  
                  SizeCOL29 NVARCHAR(5) NULL, QtyCOL29 NVARCHAR(5) NULL,  
                  SizeCOL30 NVARCHAR(5) NULL, QtyCOL30 NVARCHAR(5) NULL   
  
   DECLARE nppl_cur CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT sku, externorderkey,  
          Lottable02, Busr7 --NJOW01  
   FROM #TempNPPL  
   OPEN nppl_cur  
  
   FETCH NEXT FROM nppl_cur INTO @c_sku, @c_externorderkey,  
                                 @c_Lottable02, @c_Busr7 --NJOW01  
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
  
      DECLARE size_cur CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT substring(pd.sku,10,5) SIZE,      
             -- cast(sum(od.QtyAllocated+od.QtyPicked+od.ShippedQty) as char) Qty  --- modified by Jeff  
            cast(sum(pd.Qty) as char) Qty, -- modified by jeff  
            s.BUSR6 BUSR6              
      FROM orders o(NOLOCK)  
      JOIN orderdetail od(NOLOCK) on (o.orderkey = od.orderkey AND o.storerkey = od.storerkey)  
      JOIN pickdetail pd(NOLOCK) on (od.orderlinenumber = pd.orderlinenumber AND od.sku = pd.sku AND o.orderkey = pd.orderkey)  
      JOIN sku s(NOLOCK) on (pd.sku = s.sku AND pd.storerkey = s.storerkey)  
      JOIN lotattribute L (NOLOCK) ON (pd.lot = L.Lot) --NJOW01  
      WHERE o.externorderkey = @c_externorderkey    
      AND substring(pd.sku,1,9) = dbo.fnc_RTrim(dbo.fnc_LTrim(substring(@c_sku, 1,9)))  
      AND L.Lottable02 = @c_Lottable02  --NJOW01  
      AND LEFT(ISNULL(S.BUSR7,''),2) =  @c_Busr7 --NJOW01  
      GROUP BY substring(pd.sku,10,5),od.userdefine01, s.BUSR6  
      ORDER BY od.userdefine01, s.BUSR6  
      OPEN size_cur  
  
      SELECT @c_loopcnt = 1  
      FETCH NEXT FROM size_cur INTO @c_size, @c_qty, @C_BUSR6  
  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
  
         SELECT @theSQLStmt = 'UPDATE #TempNPPL SET SizeCOL'+dbo.fnc_RTrim(cast(@c_loopcnt as char))+'=N'''+dbo.fnc_RTrim(@c_size)  
         SELECT @theSQLStmt = @theSQLStmt+''', QtyCOL'+dbo.fnc_RTrim(cast(@c_loopcnt as char))+'=N'''+dbo.fnc_RTrim(@c_qty)+''''  
         SELECT @theSQLStmt = @theSQLStmt+' WHERE dbo.fnc_LTrim(SUBSTRING(sku,1,9)) = N'''+dbo.fnc_RTrim(dbo.fnc_LTrim(SUBSTRING(@c_sku,1,9)))+''' AND externorderkey = N'''+dbo.fnc_RTrim(dbo.fnc_LTrim(@c_externorderkey))+''''  
         SELECT @theSQLStmt = @theSQLStmt+' AND Lottable02 =  ''' + RTRIM(@c_Lottable02) + ''' AND Busr7 = ''' + RTRIM(@c_Busr7) + ''' '  --NJOW01  
         EXEC(@theSQLStmt)  
     
         SELECT @c_loopcnt = @c_loopcnt + 1  
         FETCH NEXT FROM size_cur INTO @c_size, @c_qty, @C_BUSR6  
      END -- size_cur WHILE loop  
  
      CLOSE size_cur  
      DEALLOCATE size_cur  
     
      FETCH NEXT FROM nppl_cur INTO @c_sku, @c_externorderkey,  
                                    @c_Lottable02, @c_Busr7 --NJOW01  
   END -- nppl_cur WHILE loop  
  
   CLOSE nppl_cur  
   DEALLOCATE nppl_cur  
  
   SELECT *  
   FROM #TempNPPL  
   ORDER BY ORD_Route,externorderkey                  --(CS02)  
   --ORDER BY externorderkey, sku, lottable02  -- added by Ong sos sos34681 050608   --(CS01)  
   --ORDER BY ORD_Route,ord_consigneekey,externorderkey    --(CS02)  
                      
   DROP TABLE #TempNPPL  
  
END  
  


GO