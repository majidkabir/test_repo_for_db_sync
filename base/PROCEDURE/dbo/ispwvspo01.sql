SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispWVSPO01                                         */
/* Creation Date: 09-SEP-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15102 - CN Natural Beauty - Splitting Partial and       */
/*                      UnAllocated Order in a Wave to New Order.       */
/*                      Not copy userdefine04 and trackingno            */
/* Storerconfig: WAVESPLITORDER_SP                                      */
/*                                                                      */
/* Called By: Wave (isp_SplitWaveNotFullAllocOrder_Wrapper)             */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispWVSPO01]
   @c_wavekey  NVARCHAR(10),
   @b_success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int

   DECLARE @c_orderkey NVARCHAR(10),
           @c_neworderkey NVARCHAR(10),
           @c_newloadkey NVARCHAR(10),
           @n_newordcnt int,
           @n_moveordcnt int,
           @c_status NVARCHAR(10)
           
   CREATE TABLE #TMP_NEWORDERS (Orderkey NVARCHAR(10) NULL, OldOrderkey NVARCHAR(10) NULL, Rectype NVARCHAR(1) NULL)
                         
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
       
   --BEGIN TRAN
   	
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT @c_status = status
   	  FROM Wave (NOLOCK)
   	  WHERE Wavekey = @c_Wavekey
   	  
   	  IF @c_status = '9'
   	  BEGIN
   	  	 SELECT @c_errmsg = RTRIM(@c_status) +' - Wave is closed. Splitting of Orders are not allowed'
   	  	 SELECT @n_continue = 4
   	  END  
   END   
      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT ORDERDETAIL.Orderkey, ORDERDETAIL.Orderlinenumber, ORDERDETAIL.Openqty - (ORDERDETAIL.Qtyallocated +  ORDERDETAIL.Qtypicked) AS balqty,
   	         (ORDERDETAIL.Qtyallocated + ORDERDETAIL.Qtypicked) AS openqty
   	  INTO #TMP_ORDER
   	  FROM WAVE (NOLOCK)
   	  JOIN WAVEDETAIL (NOLOCK) ON (WAVE.Wavekey = WAVEDETAIL.Wavekey)
   	  JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   	  JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
   	  WHERE WAVE.Status <> '9'
   	  AND ORDERDETAIL.Openqty > (ORDERDETAIL.Qtyallocated +  ORDERDETAIL.Qtypicked)
   	  --AND ORDERS.Status <> '0'
   	  AND WAVE.Wavekey = @c_wavekey 
   	     	     	  
   	  SELECT @c_orderkey = ''
   	  WHILE 1=1
   	  BEGIN
   	  	 SET ROWCOUNT 1
   	  	 SELECT @c_orderkey = Orderkey
   	  	 FROM #TMP_ORDER
   	  	 WHERE Orderkey > @c_orderkey
   	  	 ORDER BY Orderkey 
   	  	 
   	  	 SELECT @n_cnt = @@ROWCOUNT
   	  	 SET ROWCOUNT 0
   	  	 IF @n_cnt = 0 
   	  	    BREAK
   	  	 
         EXECUTE nspg_GetKey
         "order",
         10,
         @c_neworderkey  OUTPUT,
         @b_success   	 OUTPUT,
         @n_err       	 OUTPUT,
         @c_errmsg    	 OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            BREAK
         END   	  	 
         
         INSERT INTO ORDERS
         (
         	OrderKey, StorerKey,	ExternOrderKey, OrderDate,	DeliveryDate, Priority,	ConsigneeKey, C_contact1,
         	C_Contact2,	C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_City, C_State,	
          C_Zip, C_Country,	C_ISOCntryCode, C_Phone1, C_Phone2,	C_Fax1, C_Fax2, C_vat, BuyerPO,
         	BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, B_Address2, B_Address3,
         	B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode, B_Phone1, B_Phone2,
         	B_Fax1, B_Fax2, B_Vat, IncoTerm,	PmtTerm, OpenQty, DischargePlace, DeliveryPlace,
         	IntermodalVehicle, CountryOfOrigin,	CountryDestination, UpdateSource, [Type], OrderGroup,
         	Door, [Route], [Stop], Notes, EffectiveDate,  ContainerType,	ContainerQty, 
         	BilledContainerQty, InvoiceNo, 
          InvoiceAmount, Salesman, GrossWeight, Capacity, Rdd, Notes2, SequenceNo,
         	Rds, SectionKey, Facility, PrintDocDate, LabelPrice, POKey,	ExternPOKey, XDockFlag, UserDefine01,
         	UserDefine02, UserDefine03, UserDefine04,	UserDefine05, UserDefine06, UserDefine07, UserDefine08,
         	UserDefine10, Issued,	DeliveryNote, PODCust, PODArrive, PODReject, PODUser, xdockpokey,
         	SpecialHandling, RoutingTool,	MarkforKey,	M_Contact1,	M_Contact2,	M_Company, M_Address1, M_Address2,
         	M_Address3,	M_Address4,	M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2,
         	M_Fax1, M_Fax2, M_vat, ShipperKey, DocType, TrackingNo 
         	-- AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, SOStatus, [Status], LoadKey,  PrintFlag, MBOLKey, UserDefine09
         )
         SELECT @c_neworderkey, StorerKey,	ExternOrderKey, OrderDate,	DeliveryDate, Priority,	ConsigneeKey, C_contact1,
         	      C_Contact2,	C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_City, C_State,	
                C_Zip, C_Country,	C_ISOCntryCode, C_Phone1, C_Phone2,	C_Fax1, C_Fax2, C_vat, BuyerPO,
         	      BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, B_Address2, B_Address3,
         	      B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode, B_Phone1, B_Phone2,
         	      B_Fax1, B_Fax2, B_Vat, IncoTerm,	PmtTerm, OpenQty, DischargePlace, DeliveryPlace,
         	      IntermodalVehicle, CountryOfOrigin,	CountryDestination, UpdateSource, [Type], @c_orderkey,
         	      Door, [Route], [Stop], Notes, EffectiveDate,  ContainerType,	ContainerQty, 
         	      BilledContainerQty, InvoiceNo, 
                InvoiceAmount, Salesman, GrossWeight, Capacity, Rdd, Notes2, SequenceNo,
         	      Rds, SectionKey, Facility, PrintDocDate, LabelPrice, POKey,	ExternPOKey, XDockFlag, UserDefine01,
         	      UserDefine02, UserDefine03, '',	UserDefine05, UserDefine06, UserDefine07, UserDefine08,
         	      UserDefine10, Issued,	DeliveryNote, PODCust, PODArrive, PODReject, PODUser, xdockpokey,
         	      SpecialHandling, RoutingTool,	MarkforKey,	M_Contact1,	M_Contact2,	M_Company, M_Address1, M_Address2,
         	      M_Address3,	M_Address4,	M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2,
         	      M_Fax1, M_Fax2, M_vat, ShipperKey, DocType, ''
         	FROM ORDERS (NOLOCK) 
         	WHERE Orderkey = @c_orderkey

 	  	   	SELECT @n_err = @@ERROR
    	   	IF @n_err <> 0
	   	    BEGIN
	   		    SELECT @n_continue = 3
				    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30101   
				    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Orders Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				    BREAK
			    END

         INSERT INTO ORDERINFO
         (
         	OrderKey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08,
         	OrderInfo09, OrderInfo10, EComOrderId, REferenceId, StoreName, Platform, InvoiceType, PmtDate, InsuredAmount,
         	CarrierCharges, OtherCharges, PayableAmount, DeliveryMode, CarrierName, DeliveryCategory, Notes, Notes2, 
         	OTM_OrderOwner, OTM_BillTo, OTM_NotifyParty
         )
         SELECT @c_neworderkey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08,
                OrderInfo09, OrderInfo10, EComOrderId, REferenceId, StoreName, Platform, InvoiceType, PmtDate, InsuredAmount,
         	      CarrierCharges, OtherCharges, PayableAmount, DeliveryMode, CarrierName, DeliveryCategory, Notes, Notes2, 
         	      OTM_OrderOwner, OTM_BillTo, OTM_NotifyParty
         	FROM ORDERINFO (NOLOCK) 
         	WHERE Orderkey = @c_orderkey

 	  	   	SELECT @n_err = @@ERROR
    	   	IF @n_err <> 0
	   	    BEGIN
	   		    SELECT @n_continue = 3
				    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30102   
				    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Orderinfo Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				    BREAK
			    END

         INSERT INTO ORDERDETAIL
        (
        	OrderKey, OrderLineNumber, ExternOrderKey, ExternLineNo,	Sku,	StorerKey,
        	ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty, UOM, PackKey, PickCode,	CartonGroup, Lot, 
          ID, Facility, UnitPrice, Tax01, Tax02, ExtendedPrice, UpdateSource, Lottable01,
        	Lottable02, Lottable03, Lottable04, Lottable05,Lottable06,Lottable07, Lottable08, Lottable09, Lottable10,	
		    	Lottable11,Lottable12, Lottable13, Lottable14, Lottable15,EffectiveDate, TariffKey, FreeGoodQty,	GrossWeight, 
			    Capacity, QtyToProcess, MinShelfLife, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
        	UserDefine06, UserDefine07, UserDefine08, UserDefine09, POkey, ExternPOKey,UserDefine10, EnteredQTY,
        	ConsoOrderkey, ExternConsoOrderkey, ConsoOrderLineNo, Notes, Notes2
          --OrderDetailSysId,ShippedQty, AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop
          --[Status], LoadKey, MBOLKey
        )
        SELECT @c_newOrderKey, RIGHT(REPLICATE('0',5) + LTRIM(RTRIM(STR(1 + (SELECT COUNT(DISTINCT Orderlinenumber) 
                                                     							           FROM #TMP_ORDER AS Rank 
                                                     							           WHERE Rank.Orderlinenumber < #TMP_ORDER.Orderlinenumber
                                                     							           AND Rank.Orderkey = @c_orderkey)))),5), 
               OD.ExternOrderKey, OD.ExternLineNo,	OD.Sku,	OD.StorerKey,
        	     OD.ManufacturerSku, OD.RetailSku, OD.AltSku, #TMP_ORDER.balqty, #TMP_ORDER.balqty, OD.UOM, OD.PackKey, OD.PickCode,	OD.CartonGroup, OD.Lot,
               OD.ID, OD.Facility, OD.UnitPrice, OD.Tax01, OD.Tax02, OD.ExtendedPrice, OD.UpdateSource, OD.Lottable01,
        	     OD.Lottable02, OD.Lottable03, OD.Lottable04, OD.Lottable05, OD.Lottable06,OD.Lottable07, OD.Lottable08, OD.Lottable09, OD.Lottable10, 
				       OD.Lottable11,OD.Lottable12, OD.Lottable13, OD.Lottable14, OD.Lottable15, OD.EffectiveDate, OD.TariffKey, OD.FreeGoodQty, 
			 		     OD.GrossWeight, OD.Capacity,OD.QtyToProcess, OD.MinShelfLife, OD.UserDefine01, OD.UserDefine02, OD.UserDefine03, OD.UserDefine04, 
					     OD.UserDefine05,OD.UserDefine06, OD.UserDefine07, OD.UserDefine08, OD.UserDefine09, OD.POkey, OD.ExternPOKey, OD.UserDefine10, OD.EnteredQTY,
        	     OD.ConsoOrderkey, OD.ExternConsoOrderkey, OD.ConsoOrderLineNo, OD.Notes, OD.Notes2					     
        FROM ORDERDETAIL OD (NOLOCK)
        JOIN #TMP_ORDER ON (OD.Orderkey = #TMP_ORDER.Orderkey AND OD.Orderlinenumber = #TMP_ORDER.Orderlinenumber)
        WHERE OD.Orderkey = @c_orderkey
        ORDER BY #TMP_ORDER.Orderlinenumber

  	   	SELECT @n_err = @@ERROR
   	   	IF @n_err <> 0
   	    BEGIN
   		    SELECT @n_continue = 3
			    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30103
			    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Orderdetail Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			    BREAK
		    END		    		    
        
        UPDATE ORDERS WITH (ROWLOCK)
        SET OrderGroup = @c_orderkey,
            TrafficCop = NULL,
            openqty = (SELECT SUM(OD.Openqty) FROM ORDERDETAIL OD (NOLOCK) WHERE OD.Orderkey = @c_neworderkey)
        WHERE Orderkey = @c_neworderkey

  	   	SELECT @n_err = @@ERROR
   	   	IF @n_err <> 0
   	    BEGIN
   		    SELECT @n_continue = 3
			    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30104
			    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orders Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			    BREAK
		    END

        DELETE PREALLOCATEPICKDETAIL
        FROM PREALLOCATEPICKDETAIL P (NOLOCK)
        JOIN #TMP_ORDER ON (P.Orderkey = #TMP_ORDER.Orderkey AND P.Orderlinenumber = #TMP_ORDER.Orderlinenumber)
        WHERE #TMP_ORDER.Orderkey = @c_orderkey
  	   	SELECT @n_err = @@ERROR

   	   	IF @n_err <> 0
   	    BEGIN
   		    SELECT @n_continue = 3
			    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30105
			    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete Preallocatepickdetail Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			    BREAK
		    END		    		    
        
        UPDATE ORDERDETAIL WITH (ROWLOCK)
        SET ORDERDETAIL.Openqty = #TMP_ORDER.Openqty
            --ORDERDETAIL.TrafficCop = NULL
        FROM ORDERDETAIL OD 
        JOIN #TMP_ORDER ON (OD.Orderkey = #TMP_ORDER.Orderkey AND OD.Orderlinenumber = #TMP_ORDER.Orderlinenumber)
        WHERE OD.Orderkey = @c_orderkey

  	   	SELECT @n_err = @@ERROR
   	   	IF @n_err <> 0
   	    BEGIN
   		    SELECT @n_continue = 3
			    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 301066
			    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orderdetail Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			    BREAK
		    END
        
        INSERT #TMP_NEWORDERS (Orderkey, OldOrderkey, Rectype) VALUES (@c_neworderkey, @c_orderkey, 'N')        

  	   	SELECT @n_err = @@ERROR
   	   	IF @n_err <> 0
   	    BEGIN
   		    SELECT @n_continue = 3
			    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30107
			    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TMP_NEWORDER Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			    BREAK
		    END
   	  END  -- while
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  /*
   	  INSERT #TMP_NEWORDERS (Orderkey, OldOrderkey, Rectype)
   	  SELECT WAVEDETAIL.Orderkey, WAVEDETAIL.Orderkey, 'O'
   	  FROM WAVEDETAIL (NOLOCK) 
   	  JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   	  WHERE WAVEDETAIL.Loadkey = @c_wavekey
   	  AND ORDERS.Status = '0'

 	   	SELECT @n_err = @@ERROR
 	   	IF @n_err <> 0
  	  BEGIN
  	    SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30108
			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TMP_NEWORDERS Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			  GOTO ERR
		  END
      */
      
   	  IF (SELECT COUNT(1) FROM #TMP_NEWORDERS) = 0
   	  BEGIN
   	  	 SELECT @c_errmsg = 'No Orders to Split'
   	  	 SELECT @n_continue = 4
   	  END
   END
   
   /*
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  UPDATE LOADPLAN WITH (ROWLOCK)
   	  SET ExternLoadkey = loadkey,
   	      TrafficCop = NULL
   	  WHERE Loadkey = @c_loadkey

 	   	SELECT @n_err = @@ERROR
 	   	IF @n_err <> 0
  	  BEGIN
  	    SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30109
			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Loadplan Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		  END
   	     	  
   	  EXECUTE nspg_GetKey
        "loadkey",
        10,
        @c_newloadkey  OUTPUT,
        @b_success   	 OUTPUT,
        @n_err       	 OUTPUT,
        @c_errmsg    	 OUTPUT
        IF NOT @b_success = 1
        BEGIN
           SELECT @n_continue = 3
        END
   END
   */
   
   /*
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN        
   	
   	  SELECT * 
   	  INTO #TMP_LPDETAIL
   	  FROM LOADPLANDETAIL (NOLOCK)
      WHERE LOADPLANDETAIL.Loadkey = @c_loadkey
   	  
      DELETE LOADPLANDETAIL
      FROM LOADPLANDETAIL 
      JOIN #TMP_NEWORDERS ON (LOADPLANDETAIL.Orderkey = #TMP_NEWORDERS.OldOrderkey AND #TMP_NEWORDERS.Rectype='O')
      WHERE LOADPLANDETAIL.Loadkey = @c_loadkey

  	  SELECT @n_err = @@ERROR
 	    IF @n_err <> 0
  	  BEGIN
  	    SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30110
			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete Loadplandetail Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			  GOTO ERR
		  END

      INSERT INTO LoadPlan
       (
       	LoadKey, TruckSize,	SuperOrderFlag, SectionKey, CarrierKey, [Route], TrfRoom, DummyRoute, facility,
       	Vehicle_Type, Driver, Delivery_Zone, Truck_Type, Load_Userdef1, Load_Userdef2, weightlimit, volumelimit,
       	lpuserdefdate01, ExternLoadKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
       	UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10 
       )
       SELECT @c_newloadkey, TruckSize,	SuperOrderFlag, SectionKey, CarrierKey, [Route], TrfRoom, DummyRoute, facility,
            	Vehicle_Type, Driver, Delivery_Zone, Truck_Type, Load_Userdef1, Load_Userdef2, weightlimit, volumelimit,
       	      lpuserdefdate01, @c_loadkey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
            	UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10 
       FROM LOADPLAN (NOLOCK)
       WHERE Loadkey = @c_loadkey

  	   SELECT @n_err = @@ERROR
 	   	 IF @n_err <> 0
  	   BEGIN
  	     SELECT @n_continue = 3
			   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30108
			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Loadplan Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
 			   GOTO ERR
		   END
       
      INSERT INTO LoadPlanDetail
      (
      	LoadKey, LoadLineNumber, OrderKey, ExternOrderKey, ConsigneeKey, CustomerName, Priority, OrderDate,
      	DeliveryDate, DeliveryPlace, [Type], Door, [Stop], [Route],	NoOfOrdLines,	Rdd,	UserDefine01,
        UserDefine02, UserDefine03, UserDefine04,	UserDefine05, UserDefine06,	UserDefine07,
      	UserDefine08,	UserDefine09, UserDefine10,	ExternLoadKey, ExternLineNo, Status
      )
      SELECT @c_newloadkey, RIGHT(REPLICATE('0',5) + LTRIM(RTRIM(STR(1 + (SELECT COUNT(DISTINCT Orderkey) 
                                                     							           FROM #TMP_NEWORDERS AS Rank 
                                                     							           WHERE Rank.Orderkey < #TMP_NEWORDERS.Orderkey)))),5),  
             #TMP_NEWORDERS.OrderKey, LD.ExternOrderKey, LD.ConsigneeKey, LD.CustomerName, LD.Priority, LD.OrderDate,
       	     LD.DeliveryDate, LD.DeliveryPlace, LD.Type, LD.Door, LD.Stop, LD.Route, COUNT(OD.Orderlinenumber) AS NoOfOrdLines,	LD.Rdd,	LD.UserDefine01,
             LD.UserDefine02, LD.UserDefine03, LD.UserDefine04,	LD.UserDefine05, LD.UserDefine06,	LD.UserDefine07,
             LD.UserDefine08,	LD.UserDefine09, LD.UserDefine10,	@c_loadkey, LD.LoadLineNumber, '0'
      FROM #TMP_LPDETAIL LD (NOLOCK) 
      JOIN #TMP_NEWORDERS ON (LD.Orderkey = #TMP_NEWORDERS.OldOrderkey)
      JOIN ORDERDETAIL OD (NOLOCK) ON (#TMP_NEWORDERS.Orderkey = OD.Orderkey)
      AND LD.Loadkey = @c_loadkey
      GROUP BY #TMP_NEWORDERS.OrderKey, LD.ExternOrderKey, LD.ConsigneeKey, LD.CustomerName, LD.Priority, LD.OrderDate,
       	     LD.DeliveryDate, LD.DeliveryPlace, LD.Type, LD.Door, LD.Stop, LD.Route, LD.Rdd,	LD.UserDefine01,
             LD.UserDefine02, LD.UserDefine03, LD.UserDefine04,	LD.UserDefine05, LD.UserDefine06,	LD.UserDefine07,
             LD.UserDefine08,	LD.UserDefine09, LD.UserDefine10,	LD.LoadLineNumber
      ORDER BY #TMP_NEWORDERS.Orderkey

  	  SELECT @n_err = @@ERROR
 	    IF @n_err <> 0
  	  BEGIN
  	    SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30109
			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Loadplandetail Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			  GOTO ERR
		  END
		  
		  UPDATE ORDERDETAIL WITH (ROWLOCK)
		  SET ORDERDETAIL.Loadkey = @c_newloadkey,
		      ORDERDETAIL.Trafficcop = NULL
		  FROM ORDERDETAIL 
		  JOIN #TMP_NEWORDERS	N ON (ORDERDETAIL.Orderkey = N.Orderkey)
		  WHERE N.rectype = 'N'
		  
   	  SELECT @n_err = @@ERROR
 	    IF @n_err <> 0
  	  BEGIN
  	    SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 30110
			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orderdetail Table. (ispWVSPO01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			  GOTO ERR
		  END
   END	
   */
      	
	IF (@n_continue = 1 OR @n_continue = 2) AND @n_err = 0
	BEGIN
		 SELECT @n_newordcnt = COUNT(orderkey)
		 FROM #TMP_NEWORDERS
		 WHERE rectype = 'N'

		 /*
		 SELECT @n_moveordcnt = COUNT(orderkey)
		 FROM #TMP_NEWORDERS
		 WHERE rectype = 'O'
				 
		 SELECT @c_errmsg = RTRIM(LTRIM(STR(@n_newordcnt))) + ' Orders Created. ' + RTRIM(LTRIM(STR(@n_moveordcnt))) + ' Not Allocated orders Moved to New LoadPlan# ' + @c_newloadkey
		 */
		 SELECT @c_errmsg = RTRIM(LTRIM(STR(@n_newordcnt))) + ' New Orders Created. Check OrderGroup for Parent Order#' 
	END
   
 ERR:
 
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'ispWVSPO01'
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
END -- End PROC

GO