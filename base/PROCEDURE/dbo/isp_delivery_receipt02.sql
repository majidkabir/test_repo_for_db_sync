SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Delivery_Receipt02                             */
/* Creation Date: 2009-11-06                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  Delivery Receipt Report For PMPMI Philippines (SOS#148789) */
/*                                                                      */
/* Input Parameters:  @c_mbolkey  - MBOL Key                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_delivery_receipt02                 */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from MBOL                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 14-Mar-2012  KHLim01   1.1   Update EditDate                         */  
/* 04-MAR-2014  YTWan     1.2   SOS#303595 - PH - Update Loading Sheet  */
/*                              RCM(Wan01)                              */ 
/* 24-Mar-2014  TLTING    1.3   SQL2012 Bug                             */    
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Receipt02] (@c_mbolkey NVARCHAR(10), @c_noofcopy NVARCHAR(5) = '1') 
AS
BEGIN
    SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        int,
             @c_errmsg            NVARCHAR(255),
             @b_success           int,
             @n_err                 int,
             @n_cnt             int,
             @n_starttcnt       int,
             @c_DRSerialno       NVARCHAR(10),
             @c_Orderkey        NVARCHAR(10),
             @n_noofcopy        int,
             @c_copydesc        NVARCHAR(20) 
      , @c_IDS_Company  NVARCHAR(45)         --(Wan01)          
    
    CREATE TABLE #NOOFCOPY (copyno int, copydesc NVARCHAR(20))
    
    SELECT @n_noofcopy = ISNULL(CONVERT(int, @c_noofcopy),1)
    IF @n_noofcopy = 0
       SELECT @n_noofcopy = 1

   SELECT @n_cnt = 1 
   WHILE @n_noofcopy > 0
   BEGIN
        IF @n_cnt = 1
           SELECT @c_copydesc = 'Original Copy'
        ELSE
           SELECT @c_copydesc = 'Duplicate Copy ' + RTRIM(CAST(@n_cnt - 1 AS NVARCHAR(5)))
           
        INSERT INTO #NOOFCOPY (copyno, copydesc)
                   VALUES (@n_cnt, @c_copydesc)
        
        SELECT @n_cnt = @n_cnt + 1
        SELECT @n_noofcopy = @n_noofcopy - 1
   END

    SELECT @n_continue = 1, @n_err = 0, @c_errmsg = '', @b_success = 1, @n_cnt = 0
   SELECT @n_starttcnt=@@TRANCOUNT
    
    SELECT STORER.StorerKey, STORER.Company, STORER.Address1, STORER.Address2, STORER.Address3, 
          STORER.Address4, STORER.Phone1, STORER.Phone2, STORER.Fax1, STORER.Fax2, 
          ORDERS.Orderkey, ORDERS.ConsigneeKey, ORDERS.C_Company, ORDERS.C_Address1, ORDERS.C_Address2, 
          ORDERS.C_Address3, ORDERS.Userdefine10, ORDERS.ExternOrderkey, ORDERS.BuyerPO,
          MBOL.MbolKey, MBOL.Carrieragent, MBOL.Vessel, MBOL.DRIVERName, MBOL.EditWho, MBOL.EditDate,
          SKU.Sku, SKU.Descr, ORDERDETAIL.UOM, SUM(ORDERDETAIL.Shippedqty) Shippedqty, SKU.Stdcube, SKU.Cost,   
          CASE WHEN PACK.PACKUOM1 = ORDERDETAIL.UOM THEN PACK.CaseCnt         
               WHEN PACK.PACKUOM2 = ORDERDETAIL.UOM THEN PACK.InnerPack       
               WHEN PACK.PACKUOM3 = ORDERDETAIL.UOM THEN PACK.Qty
               WHEN PACK.PACKUOM4 = ORDERDETAIL.UOM THEN PACK.Pallet       
               WHEN PACK.PACKUOM5 = ORDERDETAIL.UOM THEN PACK.[Cube]         
               WHEN PACK.PACKUOM6 = ORDERDETAIL.UOM THEN PACK.GrossWgt        
               WHEN PACK.PACKUOM7 = ORDERDETAIL.UOM THEN PACK.NetWgt       
               WHEN PACK.PACKUOM8 = ORDERDETAIL.UOM THEN PACK.OtherUnit1         
               WHEN PACK.PACKUOM9 = ORDERDETAIL.UOM THEN PACK.OtherUnit2
               ELSE 0
          END UOMQTY,
          CASE WHEN ISNULL(MBOLDETAIL.Userdefine01,'') <> '' THEN 'Y' ELSE 'N' END printflag,
          MBOLDETAIL.Userdefine01
    INTO #TMP_DELREC         
    FROM MBOL        WITH (NOLOCK) 
    JOIN MBOLDETAIL  WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
    JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)
    JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
    JOIN STORER      WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
    JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey 
                                   AND ORDERDETAIL.Sku = SKU.Sku)
    JOIN PACK        WITH(NOLOCK)  ON (ORDERDETAIL.Packkey = PACK.Packkey)
    WHERE MBOL.Mbolkey = @c_mbolkey
    GROUP BY STORER.StorerKey, STORER.Company, STORER.Address1, STORER.Address2, STORER.Address3, 
         STORER.Address4, STORER.Phone1, STORER.Phone2, STORER.Fax1, STORER.Fax2, 
         ORDERS.Orderkey, ORDERS.ConsigneeKey, ORDERS.C_Company, ORDERS.C_Address1, ORDERS.C_Address2, 
         ORDERS.C_Address3, ORDERS.Userdefine10, ORDERS.ExternOrderkey, ORDERS.BuyerPO,
         MBOL.MbolKey, MBOL.Carrieragent, MBOL.Vessel, MBOL.DRIVERName, MBOL.EditWho, MBOL.EditDate,
         SKU.Sku, SKU.Descr, ORDERDETAIL.UOM, SKU.Stdcube, SKU.Cost,   
         CASE WHEN PACK.PACKUOM1 = ORDERDETAIL.UOM  THEN PACK.CaseCnt         
              WHEN PACK.PACKUOM2 = ORDERDETAIL.UOM THEN PACK.InnerPack        
              WHEN PACK.PACKUOM3 = ORDERDETAIL.UOM THEN PACK.Qty
              WHEN PACK.PACKUOM4 = ORDERDETAIL.UOM THEN PACK.Pallet        
              WHEN PACK.PACKUOM5 = ORDERDETAIL.UOM THEN PACK.[Cube]       
              WHEN PACK.PACKUOM6 = ORDERDETAIL.UOM THEN PACK.GrossWgt         
              WHEN PACK.PACKUOM7 = ORDERDETAIL.UOM THEN PACK.NetWgt        
              WHEN PACK.PACKUOM8 = ORDERDETAIL.UOM THEN PACK.OtherUnit1       
              WHEN PACK.PACKUOM9 = ORDERDETAIL.UOM THEN PACK.OtherUnit2
              ELSE 0
         END,
         MBOLDETAIL.Userdefine01                    
                     
      SELECT @c_orderkey = ''
     WHILE 1=1
     BEGIN
        SET ROWCOUNT 1
        SELECT @c_orderkey = Orderkey
        FROM #TMP_DELREC
        WHERE Orderkey > @c_orderkey
        AND printflag = 'N'
        ORDER BY Orderkey
        
        SELECT @n_cnt = @@ROWCOUNT
        SET ROWCOUNT 0
        
        IF @n_cnt = 0
           BREAK
           
         EXECUTE nspg_GetKey 
               'DR_PMPMI',
               10,   
               @c_DRSerialNo  OUTPUT,
               @b_success      OUTPUT,
               @n_err          OUTPUT,
               @c_errmsg       OUTPUT
               
        IF @n_err <> 0 
        BEGIN
             SELECT @n_continue = 3
             BREAK
        END
        ELSE
        BEGIN
          UPDATE #TMP_DELREC
          SET Userdefine01 = @c_DRSerialNo,
              Userdefine10 = @c_DRSerialNo
          WHERE Orderkey = @c_orderkey
          
          UPDATE MBOLDETAIL WITH (ROWLOCK)
          SET userdefine01 = @c_DRSerialNo,
              EditDate = GETDATE(), -- KHLim01
              TrafficCop = NULL                 
          WHERE Mbolkey = @c_mbolkey
          AND Orderkey = @c_Orderkey
           
          SELECT @n_err = @@ERROR
           IF @n_err <> 0 
           BEGIN
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62314   
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update MBOL Failed. (isp_Delivery_Receipt02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
              BREAK
           END
           
          UPDATE Orders WITH (ROWLOCK)
          SET userdefine10 = @c_DRSerialNo,
              EditDate = GETDATE(), -- KHLim01
              TrafficCop = NULL                 
          WHERE Orderkey = @c_Orderkey
           
          SELECT @n_err = @@ERROR
           IF @n_err <> 0 
           BEGIN
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62315   
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Orders Failed. (isp_Delivery_Receipt02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
              BREAK
           END
        END                        
     END
                                                
   IF @n_continue = 1 OR @n_continue = 2                               
   BEGIN
      --(Wan01) - START
      SET  @c_IDS_Company = ''

      SELECT @c_IDS_Company = ISNULL(RTRIM(Company),'')
      FROM STORER WITH (NOLOCK)
      WHERE Storerkey = 'IDS'

      IF @c_IDS_Company = ''
      BEGIN
         SET @c_IDS_Company = 'LF (Philippines), Inc.' 
      END
      --(Wan01) - END

      SELECT a.StorerKey, a.Company, a.Address1, a.Address2, a.Address3, 
          a.Address4, a.Phone1, a.Phone2, a.Fax1, a.Fax2, 
          a.Orderkey, a.ConsigneeKey, a.C_Company, a.C_Address1, a.C_Address2, 
          a.C_Address3, a.Userdefine10, a.ExternOrderkey, a.BuyerPO,
          a.MbolKey, a.Carrieragent, a.Vessel, a.DRIVERName, a.EditWho, a.EditDate,
          a.Sku, a.Descr, a.UOM, CASE WHEN a.UOMQTY > 0 THEN (a.Shippedqty / a.UOMQty) ELSE a.Shippedqty END AS uomqty,
          a.ShippedQty, (a.Stdcube * a.ShippedQty) AS totcbm, (a.Cost * a.ShippedQty) AS totcost, 
          a.printflag, a.Userdefine01, b.copyno, b.copydesc
      --(Wan01) - START
      , @c_IDS_Company 
      --(Wan01) - END

      FROM #TMP_DELREC a
      JOIN #NOOFCOPY b ON (1=1)
   END
/*   ELSE
   BEGIN    
        SELECT StorerKey, Company, Address1, Address2, Address3, 
             Address4, Phone1, Phone2, Fax1, Fax2, 
             Orderkey, ConsigneeKey, C_Company, C_Address1, C_Address2, 
             C_Address3, Userdefine10, ExternOrderkey, BuyerPO,
             MbolKey, Carrieragent, Vessel, DRIVERName, EditWho, EditDate,
             Sku, Descr, UOM, CASE WHEN UOMQTY > 0 THEN (Shippedqty / UOMQty) ELSE Shippedqty END AS uomqty,
             ShippedQty, (Stdcube * ShippedQty) AS totcbm, (Cost * ShippedQty) AS totcost,
             printflag, Userdefine01
       FROM #TMP_DELREC
       WHERE 1=2
   END*/
                                  
   IF @n_continue = 3  -- Error Occured - Process And Return
    BEGIN
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_Delivery_Receipt02'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
       RETURN
    END  
END                                       

GO