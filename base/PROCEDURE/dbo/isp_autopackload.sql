SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Stored Procedure: isp_AutoPackLoad                                     */
/* Creation Date: 04-Aug-2009                                             */
/* Copyright: IDS                                                         */
/* Written by: NJOW                                                       */
/*                                                                        */
/* Purpose: SOS#141877 - Auto pack loadplan for full carton               */
/*                                                                        */
/* Called By: nep_w_loadplan_maintenance                                  */
/*                                                                        */
/* Parameters:                                                            */
/*                                                                        */
/* PVCS Version: 1.1	                                                     */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver.  Purposes                                  */
/* 07/12/2009   KKY       1.1   - Modified SQL as not all discrete		  */
/*	                               have a loadkey, removed lot from sql,   */
/*	                               remove loadplandetail as orders have    */
/*	                               loadkey and change PD.QTY to            */
/*                                sum(PD.Qty)                             */
/*                              - Update number of cartons in packheader  */
/*                              - Added @c_pickslipno <> @c_prevpickslipno*/
/*                                make sure it different pickslipno and   */
/*                                not ''                                  */
/*                              - Modified pickslipno+orderkey+altsku to  */
/*                                RTRIM(PickSlipNo) + RTRIM(OrderKey) +   */
/*                                RTRIM(AltSku) (KKY200912071552)         */
/* 26/01/2010   NJOW01    1.2   156324 - Update packheader status to '9'  */ 
/*                              if the order is fully packed.             */
/**************************************************************************/

CREATE PROCEDURE [dbo].[isp_AutoPackLoad]
   @c_loadkey  NVARCHAR(10),
   @b_success  Int OUTPUT,
   @n_err      Int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  Int,
           @n_cnt       Int,
           @n_starttcnt Int

   DECLARE @c_orderkey       NVARCHAR(10),
           @c_storerkey      NVARCHAR(15),
           @c_altsku         NVARCHAR(20),
           @c_sku            NVARCHAR(20),
           @c_compsku        NVARCHAR(20),
           @n_compqty        Int,
           @n_qty            Int,
           @n_cartonno       Int,
           @n_labelline      Int,
           @c_labelline      NVARCHAR(5),
           @c_pickslipno     NVARCHAR(10),
           @c_prevpickslipno NVARCHAR(10),
           @n_rowid          Int,
           @c_prepack        NVARCHAR(1),
           @n_noofctn        Int,
           @c_labelno        NVARCHAR(20),
           @n_cartoncnt      Int,
           @n_loosecnt       Int,
           @c_route          NVARCHAR(10),
           @c_consigneekey   NVARCHAR(15),
           @c_externorderkey NVARCHAR(30)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      --KKY200912051552 - Start      
      --SELECT IDENTITY(Int,1,1) AS rowid, PD.Storerkey, PD.Sku, PD.Altsku, PD.CartonGroup, PD.Orderkey, PD.Lot, PD.Qty,
      --LA.Lottable03, CONVERT(Int,0) AS pkqty, UPC2.Packkey, PACK.casecnt, BM.QTY AS Bomqty, PH.Pickheaderkey AS pickslipno,
      --O.Route, O.Consigneekey, O.Externorderkey
      --INTO #TMP_PICKDET
      --FROM LOADPLANDETAIL LD (NOLOCK)
      --JOIN PICKDETAIL PD (NOLOCK) ON (LD.Orderkey = PD.Orderkey)
      --JOIN LOTATTRIBUTE LA (NOLOCK) ON (PD.Lot = LA.Lot)
      --JOIN (SELECT DISTINCT Storerkey,SKU,PACKKEY,UOM FROM UPC (NOLOCK)) UPC2 ON (PD.Storerkey = UPC2.Storerkey AND LA.Lottable03 = UPC2.Sku AND UPC2.Uom = 'CS')
      --JOIN PACK (NOLOCK) ON (UPC2.Packkey = PACK.Packkey)
      --JOIN BILLOFMATERIAL BM (NOLOCK) ON (PD.Storerkey = BM.Storerkey AND LA.Lottable03 = BM.SKU AND PD.SKU = BM.ComponentSku)
      --JOIN Pickheader PH (NOLOCK) ON (PH.Orderkey = PD.Orderkey AND PH.Externorderkey = LD.Loadkey AND PH.Zone = 'D')
      --JOIN ORDERS O (NOLOCK) ON (LD.Orderkey = O.Orderkey)
      --WHERE PD.Status BETWEEN '5' AND '8'
      --AND LD.Loadkey = @c_LoadKey
      
      SELECT IDENTITY(Int,1,1) AS rowid, PD.Storerkey, PD.Sku, PD.Altsku, PD.CartonGroup, PD.Orderkey, SUM(PD.Qty) As Qty, 
             LA.Lottable03, CONVERT(Int,0) AS pkqty, UPC2.Packkey, PACK.casecnt, BM.QTY AS Bomqty, PH.Pickheaderkey AS pickslipno,
             O.Route, O.Consigneekey, O.Externorderkey
      INTO #TMP_PICKDET
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON (O.Orderkey = PD.Orderkey)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON (PD.Lot = LA.Lot)
      JOIN (SELECT DISTINCT Storerkey,SKU,PACKKEY,UOM FROM UPC (NOLOCK)) UPC2 ON (PD.Storerkey = UPC2.Storerkey AND LA.Lottable03 = UPC2.Sku AND UPC2.Uom = 'CS')
      JOIN PACK (NOLOCK) ON (UPC2.Packkey = PACK.Packkey)
      JOIN BILLOFMATERIAL BM (NOLOCK) ON (PD.Storerkey = BM.Storerkey AND LA.Lottable03 = BM.SKU AND PD.SKU = BM.ComponentSku)
      JOIN Pickheader PH (NOLOCK) ON (PH.Orderkey = PD.Orderkey AND PH.Pickheaderkey = PD.Pickslipno AND PH.Zone = 'D')
      WHERE PD.Status BETWEEN '5' AND '8'
      AND O.Loadkey = @c_LoadKey
      GROUP BY PD.Storerkey, PD.Sku, PD.Altsku, PD.CartonGroup, PD.Orderkey,  
      LA.Lottable03, UPC2.Packkey, PACK.casecnt, BM.QTY, PH.Pickheaderkey,
      O.Route, O.Consigneekey, O.Externorderkey
      --KKY200912051552 - End

		 IF @@ROWCOUNT = 0
		    SELECT @n_continue = 4


		 SELECT DISTINCT TP.Orderkey, BM.Storerkey, BM.SKU, BM.ComponentSku, BM.Qty
		 INTO #TMP_BOM
		 FROM #TMP_PICKDET TP (NOLOCK)
		 JOIN BILLOFMATERIAL BM (NOLOCK) ON (TP.Storerkey = BM.Storerkey AND TP.Lottable03 = BM.SKU)
		 WHERE ISNULL(RTRIM(TP.AltSku),'') = ''
  	 AND cartongroup <> 'PREPACK'
		 ORDER BY TP.Orderkey, BM.Storerkey, BM.SKU, BM.ComponentSku

		 SELECT @c_storerkey = '', @c_sku = '', @c_orderkey = ''
		 WHILE 1=1
		 BEGIN
		 	  SET ROWCOUNT 1
		 	  SELECT @c_storerkey = Storerkey, @c_sku = Sku, @c_orderkey = Orderkey
		 	  FROM #TMP_BOM
		 	  WHERE Orderkey+Storerkey+SKU > @c_orderkey+@c_storerkey+@c_sku
		 	  ORDER BY Orderkey, Storerkey, SKU

		 	  SELECT @n_cnt = @@ROWCOUNT
		 	  SET ROWCOUNT 0
        IF @n_cnt = 0
		       BREAK

		    SELECT @c_CompSku = '', @c_prepack = 'Y'
		    BEGIN TRAN
				WHILE 1=1
		    BEGIN
		    	 SET ROWCOUNT 1
	  		 	 SELECT @c_storerkey = Storerkey, @c_compsku = ComponentSku, @n_compqty = qty
 		       FROM #TMP_BOM
		       WHERE Storerkey = @c_storerkey
		       AND Sku = @c_sku
		       AND ComponentSku > @c_compSku
		       ORDER BY ComponentSku

      	 	 SELECT @n_cnt = @@ROWCOUNT
		       SET ROWCOUNT 0

           IF @n_cnt = 0
           BEGIN
		          SELECT @c_CompSku = '', @c_prepack = 'Y'
		          COMMIT TRAN
		          BEGIN TRAN
		          CONTINUE
		       END

		       WHILE @n_Compqty > 0
		       BEGIN
		       	  SELECT TOP 1 @n_rowid = rowid, @n_qty = qty-pkqty
		       	  FROM #TMP_PICKDET
		       	  WHERE Storerkey = @c_storerkey AND Sku = @c_compsku AND orderkey = @c_orderkey
		       	  AND qty - pkqty > 0
							AND ((ISNULL(RTRIM(AltSku),'') = '' AND cartongroup <> 'PREPACK') OR pkqty > 0)
		       	  ORDER BY 2 DESC
		       	  		       	 		       	  
		       	  IF @@ROWCOUNT = 0
		       	  BEGIN
		       	     SELECT @c_prepack = 'N'
		       	     BREAK
		       	  END
		       	  IF @n_Compqty >= @n_qty
		       	  BEGIN
  		       	  UPDATE #TMP_PICKDET
	  	       	  SET pkqty = pkqty + @n_qty,
	  	       	      altsku = @c_sku, cartongroup = 'PREPACK'
	  	       	  WHERE rowid = @n_rowid

	  	       	  SELECT @n_Compqty = @n_Compqty - @n_qty
		       	  END
		       	  ELSE
		       	  BEGIN
  		       	  UPDATE #TMP_PICKDET
	  	       	  SET pkqty = pkqty + @n_Compqty,
	  	       	      altsku = @c_sku, cartongroup = 'PREPACK'
	  	       	  WHERE rowid = @n_rowid

	  	       	  SELECT @n_Compqty = 0
		       	  END
		       END -- while 3
		       IF @c_prepack = 'N'
		       BEGIN
		       	  ROLLBACK TRAN
		          BREAK
		       END
		    END	-- while 2
		 END -- while 1

		 SELECT Storerkey, Sku, Altsku, Orderkey, Qty, Packkey, Casecnt, Bomqty, pickslipno, Route, Consigneekey, Externorderkey
		 INTO #TMP_PICKDET2
		 FROM #TMP_PICKDET
		 WHERE pkqty = 0
		 AND cartongroup = 'PREPACK'

		 INSERT INTO #TMP_PICKDET2
		 SELECT Storerkey, Sku, Altsku, Orderkey, pkqty, Packkey, Casecnt, Bomqty, pickslipno, Route, Consigneekey, Externorderkey
		 FROM #TMP_PICKDET
		 WHERE pkqty > 0

		 SELECT Storerkey, sku, Altsku, Orderkey, sum(qty) AS qty, Packkey, Casecnt, Bomqty, pickslipno,
		        floor(Sum(qty) / (Casecnt * Bomqty)) AS Noofctn, Route, Consigneekey, Externorderkey
		 INTO #TMP_PICKDET3
		 FROM #TMP_PICKDET2
		 GROUP BY Storerkey, sku, Altsku, Orderkey, Packkey, Casecnt, Bomqty, pickslipno, Route, Consigneekey, Externorderkey

		 SELECT @n_cartoncnt = COUNT(*)
		 FROM #TMP_PICKDET
		 WHERE cartongroup = 'PREPACK'

		 SELECT @n_loosecnt = COUNT(*)
		 FROM #TMP_PICKDET
		 WHERE (cartongroup <> 'PREPACK')
		 OR (pkqty > 0 AND qty - pkqty > 0)

	END --continue

  WHILE @n_starttcnt > @@TRANCOUNT
     BEGIN TRAN

BEGIN TRAN
	IF @n_continue = 1 OR @n_continue = 2
  BEGIN
		 SELECT @c_orderkey = '', @c_pickslipno = '', @c_altsku = '', @c_prevpickslipno = '', @n_cartonno = 0, @c_pickslipno = ''
		 WHILE 1=1
		 BEGIN
		 	 SET ROWCOUNT 1
			 SELECT @c_orderkey = Orderkey, @c_altsku = Altsku, @c_pickslipno = pickslipno,
			        @n_noofctn = MIN(noofctn), @c_storerkey = storerkey,
			        @c_route = Route, @c_consigneekey = Consigneekey, @c_externorderkey = Externorderkey
			 FROM #TMP_PICKDET3
			 --WHERE pickslipno+orderkey+altsku > @c_pickslipno+@c_orderkey+@c_altsku --KKY200912051552
			 WHERE RTRIM(pickslipno)+RTRIM(orderkey)+RTRIM(altsku) > @c_pickslipno+@c_orderkey+@c_altsku
			 GROUP BY pickslipno, orderkey, altsku, storerkey, route, consigneekey, externorderkey
			 HAVING MIN(noofctn) > 0
			 ORDER BY pickslipno, orderkey, altsku

			 SELECT @n_cnt = @@ROWCOUNT
			 SET ROWCOUNT 0
 			 IF @n_cnt = 0
			    BREAK

		 	 IF @c_pickslipno <> @c_prevpickslipno
		 	 BEGIN
		 	 	  --IF @c_prevpickslipno <> '' --KKY200912051552: Make sure it is different pickslipno and not ''
		 	 	  IF @c_prevpickslipno <> '' AND @c_pickslipno <> @c_prevpickslipno
		 	 	  BEGIN
		 	 	     UPDATE PACKHEADER WITH (ROWLOCK)
		 	 	     SET ttlcnts = @n_cartonno - 1, archivecop = NULL
		 	 	     WHERE pickslipno = @c_prevpickslipno
		 	 	     
		 	 	     --NJOW01 Start
		 	 	     SELECT OrderDetail.StorerKey,   
                  	OrderDetail.Sku,   
                  	Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) PickedQty,   
                  	PackedQty = ISNULL((SELECT SUM(PACKDETAIL.Qty)   
                  			FROM PACKDETAIL(NOLOCK)   
                  			WHERE PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
                  			AND PACKDETAIL.Storerkey = OrderDetail.Storerkey     
                  			AND PACKDETAIL.SKU = OrderDetail.SKU), 0)
             INTO #TMP_PICKPACK
             FROM OrderDetail WITH (NOLOCK), PickHeader WITH (NOLOCK) 
             WHERE OrderDetail.Orderkey = PickHeader.OrderKey   
             AND	 PickHeader.PickHeaderkey = @c_prevpickslipno
             GROUP BY PickHeader.PickHeaderkey,  OrderDetail.StorerKey, OrderDetail.Sku  
             HAVING Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) > 0 
             
             IF (SELECT COUNT(1) FROM #TMP_PICKPACK WHERE PickedQty <> PackedQty) = 0
             BEGIN
  	 	  	 	    UPDATE PACKHEADER WITH (ROWLOCK)
		 	 	        SET status = '9'
		 	 	        WHERE pickslipno = @c_prevpickslipno
             END
             DROP TABLE #TMP_PICKPACK
             --NJOW01 End
		 	 	  END

		 	    SELECT @n_cartonno = 1
  			  SELECT @c_prevpickslipno = @c_pickslipno
  			  INSERT INTO PACKHEADER (pickslipno, storerkey, orderkey, loadkey, route, consigneekey, orderrefno)
  			  VALUES (@c_pickslipno, @c_storerkey, @c_orderkey, @c_loadkey, @c_route, @c_consigneekey, LEFT(@c_externorderkey,18))

	  	   	SELECT @n_err = @@ERROR
    	   	IF @n_err <> 0
	   	    BEGIN
	   		    SELECT @n_continue = 3
				    SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 60101
				    SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Error Insert PACKHEADER Table. (isp_AutoPackLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			    END
		 	 END

         --KKY200912051552 - Update number of cartons in packheader (Start)
         IF @c_pickslipno = @c_prevpickslipno
         BEGIN
            UPDATE PACKHEADER WITH (ROWLOCK) 
            SET ttlcnts = ttlcnts+@n_noofctn, archivecop = NULL
            WHERE pickslipno = @c_prevpickslipno  
         END
         --KKY200912051552 - Update number of cartons in packheader (End)

			 WHILE @n_noofctn > 0
			 BEGIN

            EXECUTE isp_GenUCCLabelNo
                     @c_storerkey,
                     @c_labelno  OUTPUT,
                     @b_success  OUTPUT,
                     @n_err      OUTPUT,
                     @c_errmsg   OUTPUT

           IF @b_success = 0
           BEGIN
           	  SELECT @n_continue = 3
           	  BREAK
           END

           IF (SELECT COUNT(1) FROM PACKINFO (NOLOCK) WHERE Pickslipno = @c_pickslipno AND cartonno = @n_cartonno) = 0
           BEGIN
              INSERT INTO PACKINFO (pickslipno, cartonno, cartontype)
              VALUES (@c_pickslipno, @n_cartonno, 'STD')
           END

  		     SELECT @c_CompSku = '', @n_labelline = 1
   				 WHILE 1=1
		       BEGIN
   		    	 SET ROWCOUNT 1
	  		 	   SELECT @c_compsku = ComponentSku, @n_compqty = qty
 		         FROM BILLOFMATERIAL (NOLOCK)
		         WHERE Storerkey = @c_storerkey
		         AND Sku = @c_altsku
		         AND ComponentSku > @c_compSku
		         ORDER BY ComponentSku

      	 	   SELECT @n_cnt = @@ROWCOUNT
		         SET ROWCOUNT 0

             IF @n_cnt = 0
                BREAK

             SELECT @c_labelline = RIGHT('00000'+RTRIM(CONVERT(Char(5),@n_labelline)),5)

			 	     INSERT INTO PACKDETAIL (pickslipno, cartonno, labelno, labelline, storerkey, sku, qty)
			 	     VALUES (@c_pickslipno, @n_cartonno, @c_labelno, @c_labelline, @c_storerkey, @c_compsku, @n_compqty)

   	  	     SELECT @n_err = @@ERROR
    	   	   IF @n_err <> 0
	   	       BEGIN
	   		       SELECT @n_continue = 3
				       SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 60102
				       SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Error Insert PACKDETAIL Table. (isp_AutoPackLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			       END

					 	 SELECT @n_labelline = @n_labelline + 1
			 	   END --while 3

			 	 SELECT @n_noofctn = @n_noofctn - 1
			 	 SELECT @n_cartonno = @n_cartonno + 1
			 END -- while 2
		 END	-- while 1
		 --IF @c_pickslipno <> ''
		 IF @c_prevpickslipno <> ''
		 BEGIN
  	   UPDATE PACKHEADER WITH (ROWLOCK)
 	 	   SET ttlcnts = @n_cartonno - 1, archivecop = NULL
	 	 	 WHERE pickslipno = @c_prevpickslipno

	 	   --NJOW01 Start
		   SELECT OrderDetail.StorerKey,   
            	OrderDetail.Sku,   
            	Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) PickedQty,   
            	PackedQty = ISNULL((SELECT SUM(PACKDETAIL.Qty)   
            			FROM PACKDETAIL(NOLOCK)   
            			WHERE PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
            			AND PACKDETAIL.Storerkey = OrderDetail.Storerkey     
            			AND PACKDETAIL.SKU = OrderDetail.SKU), 0)
       INTO #TMP_PICKPACK2
       FROM OrderDetail WITH (NOLOCK), PickHeader WITH (NOLOCK) 
       WHERE OrderDetail.Orderkey = PickHeader.OrderKey   
       AND	 PickHeader.PickHeaderkey = @c_prevpickslipno
       GROUP BY PickHeader.PickHeaderkey,  OrderDetail.StorerKey, OrderDetail.Sku  
       HAVING Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) > 0 
       
       IF (SELECT COUNT(1) FROM #TMP_PICKPACK2 WHERE PickedQty <> PackedQty) = 0
       BEGIN
  	      UPDATE PACKHEADER WITH (ROWLOCK)
		      SET status = '9'
		      WHERE pickslipno = @c_prevpickslipno
       END
       DROP TABLE #TMP_PICKPACK2
       --NJOW01 End
	 	 END
	 	 

	END -- continue

	IF (@n_continue = 1 OR @n_continue = 2) AND @n_err = 0
	BEGIN
		 IF @n_cartoncnt > 0 AND @n_loosecnt = 0
		    SELECT @c_errmsg = 'Pack Information Created And Sent To GSI Spooler'

		 IF @n_cartoncnt = 0 AND @n_loosecnt > 0
		    SELECT @c_errmsg = 'All Orders are loose pieces. No Pack Information Created And Sent To GSI Spooler'

		 IF @n_cartoncnt > 0 AND @n_loosecnt > 0
		    SELECT @c_errmsg = 'Pack Information Created with Loose pieces detected And Sent To GSI Spooler'
	END

  IF @n_continue = 4
  BEGIN
     SELECT @c_errmsg = 'No Pack Information Created. No valid pickdetail found'
  END

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
  	  EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_AutoPackLoad'
	    --RAISERROR @n_err @c_errmsg
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

END -- End PROC

GO