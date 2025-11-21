SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispMBRTK05                                         */
/* Creation Date:  09-Mar-2016                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  360341-CN-Carters SZ-MBOL release Pick to split container  */
/*           orders and populate to MBOL.                               */
/*                                                                      */
/* Input Parameters:  @c_Mbolkey  - (Mbol #)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  MBOL RMC Release Pick Task                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 13-May-2016 NJOW01   1.1  Insert splitted new order to wave          */
/* 09-May-2017 JIHHAUR  1.2  IN00339674 Release Pick task no responding */
/*                           (JH01)                                     */
/* 22-Sep-2017 TLTING   1.3  Misisng NOLOCK                             */
/* 28-Jan-2019 TLTING_ext 1.4 enlarge externorderkey field length       */
/************************************************************************/

CREATE PROC [dbo].[ispMBRTK05]
   @c_MbolKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT,
   @n_Cbolkey bigint = 0   
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_StartTranCnt int
           
   DECLARE @c_Storerkey NVARCHAR(15),
           @c_ToLoc NVARCHAR(10),
           @c_ToLogicalLocation NVARCHAR(18),
           @c_ContainerKey NVARCHAR(10),
           @c_Orderkey NVARCHAR(10),
           @c_MBOLOrderkey NVARCHAR(10),
           @c_MBOLLoadkey NVARCHAR(10),
           @c_MBOLkeyFromOrder NVARCHAR(10),
           @c_NewOrderkey NVARCHAR(10),
           @c_NewLoadKey NVARCHAR(10),
           @n_ContrQty INT,
           @n_OrderQty INT,
           @c_Route NVARCHAR(10),
           @d_OrderDate DATETIME,
           @d_DeliveryDate DATETIME,
           @n_TotalCube FLOAT,
           @n_TotalGrossWgt FLOAT,
           @c_Facility NVARCHAR(5),
           @c_ExternOrderkey NVARCHAR(50),  --tlting_ext
           @c_Loadkey NVARCHAR(10),
           @c_LogicalLocation NVARCHAR(18),
           @c_ID NVARCHAR(18),
           @c_Loc NVARCHAR(10),
           @c_TaskDetailKey NVARCHAR(10),
           @n_Qty INT,
       	 	 @c_Door NVARCHAR(10),
       	 	 @c_Consigneekey NVARCHAR(15),
       	 	 @c_Type NVARCHAR(10),
       	 	 @c_DeliveryPlace NVARCHAR(30),
       	 	 @c_CustomerName NVARCHAR(45),
       	 	 @c_PickSlipno NVARCHAR(10),
       	 	 @c_OldPickSlipno NVARCHAR(10),
       	 	 @c_OrderStatus NVARCHAR(10),
       	 	 @c_OrderLineNumber NVARCHAR(5),
       	 	 @n_QtyAllocated INT,
       	 	 @n_QtyPicked INT,
       	 	 @c_NewOrderLineNumber NVARCHAR(5),
       	 	 @c_MovefromLabelNo NVARCHAR(20),
           @c_PrevMovefromLabelNo NVARCHAR(20),
       	 	 @n_NewCartonNo INT,
       	 	 @c_Movefrompickslipno NVARCHAR(10),
       	 	 @c_NewLabelLine NVARCHAR(5),
       	 	 @n_NewLabelLine INT,
       	 	 @c_MoveFromLabelLine NVARCHAR(5),
       	 	 @n_MoveFromCartonNo INT,
       	 	 @c_CaseId NVARCHAR(20),
       	 	 @c_Wavekey NVARCHAR(10),
       	 	 @c_Wavedetailkey NVARCHAR(10)        	 	 
       	 	            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = ''

   IF EXISTS (SELECT 1 FROM TASKDETAIL(NOLOCK) WHERE Sourcekey = @c_Mbolkey AND SourceType = 'ispMBRTK06') --from Release move task RCM
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Task has been released for the MBOL. Not allow to release pick again. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP    	  
   END
   
   IF @n_continue IN(1,2)
   BEGIN
   	  --Validation
   	  SET @c_Containerkey = ''   	  
   	  SET @c_CaseId = ''
      SELECT TOP 1 @c_ContainerKey = C.Containerkey, @c_CaseId = PD.CaseId
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PD.CaseID = PKD.LabelNo
      LEFT JOIN PICKDETAIL PID (NOLOCK) ON PKD.LabelNo = PID.CaseId
      WHERE C.Mbolkey = @c_Mbolkey 
      AND (PKD.LabelNo IS NULL OR PID.CaseID IS NULL)
      
      IF ISNULL(@c_ContainerKey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': CaseId ''' + RTRIM(@c_CaseId) + ''' of Container '''+ RTRIM(@c_Containerkey) +''' is not found at Packdetail or Pickdetail. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	            
   	  
   	  
   	  --Create Temp table
   	  CREATE TABLE #TMP_ORDERLINE 
   	            (Orderkey NVARCHAR(10) NULL,
   	             OrderLineNumber NVARCHAR(5) NULL,
   	             BalQty INT NULL,
   	             SplitQty INT NULL,
   	             SplitQtyAllocated INT NULL,
   	             SplitQtyPicked INT NULL)
   	             
   	  --Get staging location
   	  /*
   	  SET @c_ToLoc = ''
      SELECT TOP 1 @c_ToLoc = LLD.Loc, @c_ToLogicalLocation = LOC.LogicalLocation
      FROM LOADPLANLANDDETAIL LLD (NOLOCK)
      JOIN LOC (NOLOCK) ON LLD.Loc = LOC.Loc
      WHERE LLD.Mbolkey = @c_Mbolkey
      AND LLD.LocationCategory = 'STAGING'
      
      IF ISNULL(@c_ToLoc,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Staging lane not yet assigned to the MBOL (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
      */         	
      
      --Get container info
      SET @c_ContainerKey = ''
      SELECT TOP 1 @c_ContainerKey = C.Containerkey
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      WHERE C.Mbolkey = @c_Mbolkey 
      
      IF ISNULL(@c_ContainerKey,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Detail not found for the MBOL (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	            
   END  

   --Retrieve reference data
   IF @n_Continue IN(1,2)
   BEGIN
   	  --retrieve pickdetail of the container
   	  SELECT DISTINCT PICKD.Orderkey, PICKD.Storerkey, PICKD.Pickdetailkey, PICKD.Qty AS ContrQty
   	  INTO #TMP_PICKDETAIL
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      JOIN PACKDETAIL PKD (NOLOCK) ON PD.CaseID = PKD.LabelNo
      JOIN PACKHEADER PKH (NOLOCK) ON PKD.PickslipNo = PKH.PickslipNo
      JOIN PICKDETAIL PICKD (NOLOCK) ON PKD.LabelNo = PICKD.CaseID AND PKH.Pickslipno = PICKD.Pickslipno AND PKD.SKU = PICKD.SKU --AND PD.Id = PD.PalletKey --(JH01) add AND PKD.SKU = PICKD.SKU
      WHERE C.Mbolkey = @c_Mbolkey 
      
      --retrieve order of the container
      SELECT O.Orderkey, O.Storerkey, SUM(OD.QtyAllocated + OD.QtyPicked) AS OrderQty, 
             O.Facility, O.Loadkey, SUM(Sku.StdCube * (OD.QtyAllocated + OD.QtyPicked)) AS TotalCube,
             SUM(Sku.StdGrossWgt * (OD.QtyAllocated + OD.QtyPicked)) AS TotalGrossWgt, O.Route,
             O.OrderDate, O.DeliveryDate, O.ExternOrderkey, O.Mbolkey, O.Userdefine09 AS Wavekey
      INTO #TMP_ORDER
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      WHERE EXISTS (SELECT 1 FROM #TMP_PICKDETAIL A WHERE A.Orderkey = O.Orderkey )
      GROUP BY O.Orderkey, O.Storerkey, O.Facility, O.Loadkey, O.Route, O.OrderDate, O.DeliveryDate, O.ExternOrderkey, O.Mbolkey, O.Userdefine09     
      
      IF EXISTS (SELECT 1 FROM #TMP_ORDER WHERE ISNULL(Mbolkey,'') <> '' AND Mbolkey <> @c_Mbolkey )                     
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Orders Have Been Populated to Other MBOL (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END

      IF NOT EXISTS (SELECT 1 FROM #TMP_ORDER WHERE ISNULL(Mbolkey,'') = '')                     
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36026   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Orders Have Been Populated to MBOL (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
   END
   
   --Slip orders and populate to MBOL
   IF @n_Continue IN(1,2)
   BEGIN           
   	  IF @n_StartTranCnt = 0
   	     BEGIN TRAN
   	     	
   	  --Retrive container orders
      DECLARE CUR_CONTR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TP.Orderkey, TP.Storerkey, SUM(TP.ContrQty) AS ContrQty, TOR.OrderQty,
                TOR.Facility, TOR.Loadkey, TOR.TotalCube, TOR.TotalGrossWgt, TOR.Route,
                TOR.OrderDate, TOR.DeliveryDate, TOR.ExternOrderkey, TOR.MBOLkey, TOR.Wavekey
         FROM #TMP_PICKDETAIL TP 
         JOIN #TMP_ORDER TOR ON TP.Orderkey = TOR.Orderkey
         GROUP BY TP.Orderkey, TP.Storerkey, TOR.OrderQty, TOR.Facility, TOR.Loadkey, TOR.TotalCube, TOR.TotalGrossWgt, 
                  TOR.Route, TOR.OrderDate, TOR.DeliveryDate, TOR.ExternOrderkey, TOR.MBOLKey, TOR.Wavekey
         ORDER BY TOR.Loadkey, TP.Orderkey

      OPEN CUR_CONTR_ORDER  
      
      FETCH NEXT FROM CUR_CONTR_ORDER INTO @c_Orderkey, @c_Storerkey, @n_ContrQty, @n_OrderQty, @c_Facility, @c_Loadkey, @n_TotalCube,
                                           @n_TotalGrossWgt, @c_Route, @d_OrderDate, @d_DeliveryDate, @c_ExternOrderkey, @c_MBOLkeyFromOrder, @c_Wavekey
      
      SET @c_NewOrderkey = ''
      SET @c_NewLoadkey = ''
      SET @c_Pickslipno = ''
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)
      BEGIN
      	 SET @c_MBOLOrderkey = @c_Orderkey
      	 SET @c_MBOLLoadkey = @c_Loadkey
      	 
      	 --require split order
      	 IF @n_ContrQty <> @n_OrderQty
      	 BEGIN  
	         	IF ISNULL(@c_MBOLkeyFromOrder,'') <> ''
 	          BEGIN
	   		       SELECT @n_continue = 3
				       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36028   
				       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Split Order Failed. Order is in MBOL. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
	          END
      	 	
      	 	  --Retrieve summary order line
            DELETE FROM #TMP_ORDERLINE
           
            INSERT INTO #TMP_ORDERLINE
            SELECT PD.Orderkey, PD.OrderLineNumber, 
                  (OD.QtyAllocated + OD.QtyPicked) - SUM(TP.ContrQty) AS BalQty, 
                   SUM(TP.ContrQty) AS SplitQty,
                   SUM(CASE WHEN PD.Status IN ('0','1','2','3','4') THEN PD.Qty ELSE 0 END) AS SplitQtyAllocated,  
                   SUM(CASE WHEN PD.Status IN ('5','6','7','8') THEN PD.Qty ELSE 0 END) AS SplitQtyPicked
            FROM #TMP_PICKDETAIL TP
            JOIN PICKDETAIL PD (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey
            JOIN ORDERDETAIL OD (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
            WHERE TP.Orderkey = @c_Orderkey
            GROUP BY PD.Orderkey, PD.OrderLineNumber, OD.QtyAllocated, OD.QtyPicked
      	 	
      	 	  --Create new order and orderinfo  	 	
      	 	  IF @n_Continue IN(1,2)
      	 	  BEGIN
               EXECUTE nspg_GetKey
               'ORDER',
               10,
               @c_neworderkey  OUTPUT,
               @b_success   	 OUTPUT,
               @n_err       	 OUTPUT,
               @c_errmsg    	 OUTPUT
               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
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
               	UserDefine09, UserDefine10, Issued,	DeliveryNote, PODCust, PODArrive, PODReject, PODUser, xdockpokey,
               	SpecialHandling, RoutingTool,	MarkforKey,	M_Contact1,	M_Contact2,	M_Company, M_Address1, M_Address2,
               	M_Address3,	M_Address4,	M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2,
               	M_Fax1, M_Fax2, M_vat, ShipperKey, DocType, TrackingNo,[Status], SOStatus
               	-- AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, SOStatus, [Status], LoadKey,  PrintFlag, MBOLKey
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
               	      UserDefine02, UserDefine03, UserDefine04,	UserDefine05, UserDefine06, UserDefine07, UserDefine08,
               	      '', UserDefine10, Issued,	DeliveryNote, PODCust, PODArrive, PODReject, PODUser, xdockpokey,
               	      SpecialHandling, RoutingTool,	MarkforKey,	M_Contact1,	M_Contact2,	M_Company, M_Address1, M_Address2,
               	      M_Address3,	M_Address4,	M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2,
               	      M_Fax1, M_Fax2, M_vat, ShipperKey, DocType, TrackingNo,[Status], SOStatus
               	FROM ORDERS (NOLOCK) 
               	WHERE Orderkey = @c_orderkey
               
 	  	         	SELECT @n_err = @@ERROR
    	         	IF @n_err <> 0
	   	          BEGIN
	   		          SELECT @n_continue = 3
				          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36030   
				          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Orders Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			          END
			          
			          INSERT INTO ORDERINFO 
			          (
			           Orderkey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08,
			           OrderInfo09, OrderInfo10, EcomOrderId, ReferenceId, StoreName, PlatForm, InvoiceType, PmtDate, InsuredAmount, 
			           CarrierCharges, OtherCharges, PayableAmount, DeliveryMode, CarrierName, DeliveryCategory, Notes, Notes2, 
			           OTM_OrderOwner, OTM_BillTo, OTM_NotifyParty
			          )
			          SELECT @c_NewOrderkey, OrderInfo01, OrderInfo02, OrderInfo03, OrderInfo04, OrderInfo05, OrderInfo06, OrderInfo07, OrderInfo08,
			                 OrderInfo09, OrderInfo10, EcomOrderId, ReferenceId, StoreName, PlatForm, InvoiceType, PmtDate, InsuredAmount, 
			                 CarrierCharges, OtherCharges, PayableAmount, DeliveryMode, CarrierName, DeliveryCategory, Notes, Notes2, 
			                 OTM_OrderOwner, OTM_BillTo, OTM_NotifyParty
			          FROM ORDERINFO (NOLOCK)
			          WHERE Orderkey = @c_Orderkey       

 	  	         	SELECT @n_err = @@ERROR
    	         	IF @n_err <> 0
	   	          BEGIN
	   		          SELECT @n_continue = 3
				          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36040  
				          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert OrderInfo Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			          END
			      END            	  	
			       
            --Create new orderdetail
            IF @n_Continue IN(1,2)
            BEGIN            	 
               INSERT INTO ORDERDETAIL
               (
               	OrderKey, OrderLineNumber, ExternOrderKey, ExternLineNo,	Sku,	StorerKey,
               	ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty, UOM, PackKey, PickCode,	CartonGroup, Lot, 
                ID, Facility, UnitPrice, Tax01, Tax02, ExtendedPrice, UpdateSource, Lottable01,
               	Lottable02, Lottable03, Lottable04, Lottable05,Lottable06,Lottable07, Lottable08, Lottable09, Lottable10,	
			          Lottable11,Lottable12, Lottable13, Lottable14, Lottable15,EffectiveDate, TariffKey, FreeGoodQty,	GrossWeight, 
			          Capacity, QtyToProcess, MinShelfLife, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
               	UserDefine06, UserDefine07, UserDefine08, UserDefine09, POkey, ExternPOKey,UserDefine10, EnteredQTY, 
               	ConsoOrderkey, ExternConsoOrderkey, ConsoOrderLineNo, Notes, Notes2, [Status]
                 --OrderDetailSysId,ShippedQty, AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop
                 --[Status], LoadKey, MBOLKey
               )
               SELECT @c_newOrderKey, RIGHT(REPLICATE('0',5) + LTRIM(RTRIM(STR(1 + (SELECT COUNT(DISTINCT Rank.Orderlinenumber) 
                                                            							           FROM #TMP_ORDERLINE AS Rank 
                                                            							           WHERE Rank.Orderlinenumber < #TMP_ORDERLINE.Orderlinenumber
                                                            							           AND Rank.Orderkey = @c_orderkey)))),5), 
                      OD.ExternOrderKey, OD.ExternLineNo,	OD.Sku,	OD.StorerKey,
               	      OD.ManufacturerSku, OD.RetailSku, OD.AltSku, #TMP_ORDERLINE.SplitQty, #TMP_ORDERLINE.SplitQty, OD.UOM, OD.PackKey, OD.PickCode,	OD.CartonGroup, OD.Lot,
                      OD.ID, OD.Facility, OD.UnitPrice, OD.Tax01, OD.Tax02, OD.ExtendedPrice, OD.UpdateSource, OD.Lottable01,
               	      OD.Lottable02, OD.Lottable03, OD.Lottable04, OD.Lottable05, OD.Lottable06,OD.Lottable07, OD.Lottable08, OD.Lottable09, OD.Lottable10, 
				              OD.Lottable11,OD.Lottable12, OD.Lottable13, OD.Lottable14, OD.Lottable15, OD.EffectiveDate, OD.TariffKey, OD.FreeGoodQty, 
				       	      OD.GrossWeight, OD.Capacity,OD.QtyToProcess, OD.MinShelfLife, OD.UserDefine01, OD.UserDefine02, OD.UserDefine03, OD.UserDefine04, 
				       	      OD.UserDefine05,OD.UserDefine06, OD.UserDefine07, OD.UserDefine08, OD.UserDefine09, OD.POkey, OD.ExternPOKey, OD.UserDefine10, OD.EnteredQTY,
				       	      OD.ConsoOrderkey, OD.ExternConsoOrderkey, OD.OrderLineNumber, OD.Notes, OD.Notes2, [Status]
               FROM ORDERDETAIL OD (NOLOCK)
               JOIN #TMP_ORDERLINE ON (OD.Orderkey = #TMP_ORDERLINE.Orderkey AND OD.Orderlinenumber = #TMP_ORDERLINE.Orderlinenumber)
               WHERE OD.Orderkey = @c_orderkey
               ORDER BY #TMP_ORDERLINE.Orderlinenumber

  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36050
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Orderdetail Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END		    		    
               
               /*
               UPDATE ORDERS WITH (ROWLOCK)
               SET OrderGroup = @c_orderkey,
                   --Status = '5',
                   TrafficCop = NULL,
                   openqty = (SELECT SUM(OD.Openqty) FROM ORDERDETAIL OD (NOLOCK) WHERE OD.Orderkey = @c_neworderkey)
               WHERE Orderkey = @c_neworderkey
               
  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36060
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orders Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END
		           */		           
            END

      	 	  --Move pickdetail to new order and adjust new orderdetail and update new order group & status * openqty
            IF @n_Continue IN(1,2)
            BEGIN
            	 --Retrive order line to move
               DECLARE CUR_ORDERLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            	    SELECT TOR.OrderLineNumber, 
            	           OD.OrderLineNumber AS NewOrderLineNumber,
                         TOR.SplitQtyAllocated,  
                         TOR.SplitQtyPicked
                  FROM #TMP_ORDERLINE TOR
                  JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = @c_NewOrderkey AND TOR.OrderLineNumber = OD.ConsoOrderLineNo --link to get new order line
                  WHERE TOR.Orderkey = @c_Orderkey

               OPEN CUR_ORDERLINE  
      
               FETCH NEXT FROM CUR_ORDERLINE INTO @c_OrderLineNumber, @c_NewOrderLineNumber, @n_QtyAllocated, @n_QtyPicked
                                 
               WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)
               BEGIN
               	  --Move pickdetail to new order
                  UPDATE PICKDETAIL  WITH (ROWLOCK)
                     SET PICKDETAIL.OrderKey = @c_NewOrderKey,  
                         PICKDETAIL.OrderLineNumber = @c_NewOrderLineNumber,
                         PICKDETAIL.EditDate = GETDATE(),  
                         PICKDETAIL.TrafficCop = NULL
                  FROM PICKDETAIL 
                  JOIN #TMP_PICKDETAIL TP ON PICKDETAIL.Pickdetailkey = TP.Pickdetailkey --filter pickdetail of the container
                  WHERE PICKDETAIL.OrderKey = @c_OrderKey  
                  AND PICKDETAIL.OrderLineNumber = @c_OrderLineNumber  

  	   	          SELECT @n_err = @@ERROR
                  
   	   	          IF @n_err <> 0
   	              BEGIN
   		              SELECT @n_continue = 3
			              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36060
			              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Pickdetail Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 			              
		              END		    		    
		              
		              --Update qty to new orderdetail
                  UPDATE ORDERDETAIL  WITH (ROWLOCK) 
                     SET QtyPicked    =  @n_QtyPicked,  
                         QtyAllocated =  @n_Qtyallocated,  
                         STATUS       =  '5',  
                         --EnteredQty   =  0,  
                         EditDate = GETDATE(),  
                         TrafficCop = NULL  
                  FROM ORDERDETAIL  
                  WHERE ORDERDETAIL.OrderKey = @c_NewOrderKey  
                  AND   ORDERDETAIL.OrderLineNumber = @c_NewOrderLineNumber  
		              
  	   	          SELECT @n_err = @@ERROR
                  
   	   	          IF @n_err <> 0
   	              BEGIN
   		              SELECT @n_continue = 3
			              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36070
			              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAIL Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 			              
		              END		    		    
               	  
                  FETCH NEXT FROM CUR_ORDERLINE INTO @c_OrderLineNumber, @c_NewOrderLineNumber, @n_QtyAllocated, @n_QtyPicked
               END
               CLOSE CUR_ORDERLINE   
               DEALLOCATE CUR_ORDERLINE               
               
               UPDATE ORDERS WITH (ROWLOCK)
               SET OrderGroup = @c_orderkey,
                   Status = '5',
                   openqty = (SELECT SUM(OD.Openqty) FROM ORDERDETAIL OD (NOLOCK) WHERE OD.Orderkey = @c_neworderkey),
                   TrafficCop = NULL
               WHERE Orderkey = @c_neworderkey
               
  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36080
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orders Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END		           
            END      	 	  
      	 	  
            --Adjust original orderdetail      
            IF @n_Continue IN(1,2)
            BEGIN    
            	 /*        	 
               DELETE PREALLOCATEPICKDETAIL
               FROM PREALLOCATEPICKDETAIL P (NOLOCK)
               JOIN #TMP_ORDER ON (P.Orderkey = #TMP_ORDER.Orderkey AND P.Orderlinenumber = #TMP_ORDER.Orderlinenumber)
               WHERE #TMP_ORDER.Orderkey = @c_orderkey     
               
  	   	       SELECT @n_err = @@ERROR
               
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36019
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete Preallocatepickdetail Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END		    		    
		           */
               
               --Update qty to old orderdetail
               UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET ORDERDETAIL.Openqty = #TMP_ORDERLINE.BalQty,
                   ORDERDETAIL.OriginalQty = #TMP_ORDERLINE.BalQty,
                   ORDERDETAIL.Qtyallocated = ORDERDETAIL.Qtyallocated - #TMP_ORDERLINE.SplitQtyAllocated,
                   ORDERDETAIL.Qtypicked = ORDERDETAIL.Qtypicked - #TMP_ORDERLINE.SplitQtypicked,
                   ORDERDETAIL.TrafficCop = NULL
               FROM ORDERDETAIL 
               JOIN #TMP_ORDERLINE ON (ORDERDETAIL.Orderkey = #TMP_ORDERLINE.Orderkey AND ORDERDETAIL.Orderlinenumber = #TMP_ORDERLINE.Orderlinenumber)
               WHERE ORDERDETAIL.Orderkey = @c_orderkey
               
  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36090
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orderdetail Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END            	
		           
               UPDATE ORDERS WITH (ROWLOCK)
               SET openqty = (SELECT SUM(OD.Openqty) FROM ORDERDETAIL OD (NOLOCK) WHERE OD.Orderkey = @c_orderkey),
                   TrafficCop = NULL
               WHERE Orderkey = @c_orderkey
               
  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36100
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Orders Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END		           		           
            END
            
      	 	  --Create new Load plan if not exists
            IF @n_Continue IN(1,2)
            BEGIN            	 
               IF ISNULL(@c_NewLoadkey,'') = ''
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE nspg_GetKey
                     'LOADKEY',
                     10,
                     @c_newloadkey  OUTPUT,
                     @b_success     OUTPUT,
                     @n_err         OUTPUT,
                     @c_errmsg      OUTPUT
                  
                  IF @b_success <> 1
                  BEGIN
                    SELECT @n_continue = 3
                  END           
                  ELSE
                  BEGIN                                   
                     INSERT INTO LoadPlan
                     (
                     	LoadKey,
                     	[Status],
                     	TruckSize,
                     	SuperOrderFlag,
                     	SectionKey,
                     	CarrierKey,
                     	[Route],
                     	TrfRoom,
                     	DummyRoute,
                     	facility,
                     	PROCESSFLAG,
                     	Vehicle_Type,
                     	Driver,
                     	Delivery_Zone,
                     	Truck_Type,
                     	Load_Userdef1,
                     	Load_Userdef2,
                     	weightlimit,
                     	volumelimit,
                     	lpuserdefdate01,
                     	FinalizeFlag,
                     	UserDefine01,
                     	UserDefine02,
                     	UserDefine03,
                     	UserDefine04,
                     	UserDefine05,
                     	UserDefine06,
                     	UserDefine07,
                     	UserDefine08,
                     	UserDefine09,
                     	UserDefine10,
                     	ExternLoadKey,
                     	Priority,
                     	DispatchPalletPickMethod,
                     	DispatchCasePickMethod,
                     	DispatchPiecePickMethod,
                     	LoadPickMethod,
                     	MBOLGroupMethod,
                     	DefaultStrategykey,
                     	BookingNo
                     )
                     SELECT 
                     	@c_NewLoadkey,
                     	[Status],
                     	TruckSize,
                     	SuperOrderFlag,
                     	SectionKey,
                     	CarrierKey,
                     	[Route],
                     	TrfRoom,
                     	DummyRoute,
                     	facility,
                     	PROCESSFLAG,
                     	Vehicle_Type,
                     	Driver,
                     	Delivery_Zone,
                     	Truck_Type,
                     	Load_Userdef1,
                     	Load_Userdef2,
                     	weightlimit,
                     	volumelimit,
                     	lpuserdefdate01,
                     	FinalizeFlag,
                     	UserDefine01,
                     	UserDefine02,
                     	UserDefine03,
                     	UserDefine04,
                     	UserDefine05,
                     	UserDefine06,
                     	UserDefine07,
                     	UserDefine08,
                     	UserDefine09,
                     	UserDefine10,
                     	ExternLoadKey,
                     	Priority,
                     	DispatchPalletPickMethod,
                     	DispatchCasePickMethod,
                     	DispatchPiecePickMethod,
                     	LoadPickMethod,
                     	MBOLGroupMethod,
                     	DefaultStrategykey,
                     	BookingNo
                     FROM LOADPLAN (NOLOCK)
                     WHERE Loadkey = @c_Loadkey
                     
  	   	             SELECT @n_err = @@ERROR
   	   	             IF @n_err <> 0
   	                 BEGIN
   		                 SELECT @n_continue = 3
			                 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36110
			                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert LoadPlan Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		                 END   
		              END         	                  
               END
            END
            
       	 	  --Add new order to new load plan      
       	 	  IF @n_Continue IN(1,2)
       	 	  BEGIN       	 	  	
       	 	  	 SELECT @c_Door = O.Door, @c_Consigneekey = O.Consigneekey, @c_Type = O.Type, @c_OrderStatus = O.Status,
       	 	  	        @c_DeliveryPlace = O.DeliveryPlace, @c_CustomerName = ISNULL(S.Company,'')
       	 	  	 FROM ORDERS O (NOLOCK)
       	 	  	 LEFT JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
       	 	  	 WHERE O.Orderkey = @c_Orderkey
       	 	  	 
               EXEC isp_InsertLoadplanDetail
                    @c_NewLoadKey,
                    @c_Facility,
                    @c_NewOrderKey,
                    @c_ConsigneeKey,
                    '9', --@cPrioriry
                    @d_OrderDate ,
                    @d_DeliveryDate,
                    @c_Type,
                    @c_Door,
                    @c_Route,
                    @c_DeliveryPlace,
                    @n_TotalGrossWgt,
                    @n_TotalCube,
                    @c_ExternOrderKey,
                    @c_CustomerName,
                    0, --@nTotOrderLines
                    0, --@nNoOfCartons   
                    @c_OrderStatus,
                    @b_Success  OUTPUT,
                    @n_Err OUTPUT,
                    @c_ErrMsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert LOADPLANDETAIL Error. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                  GOTO QUIT_SP 
               END                               
       	 	  END
       	 	  
       	 	  --Add new order to wave if exists
       	 	  IF @n_Continue IN(1,2)
       	 	  BEGIN       	 	  	       	 	  	 
               IF EXISTS(SELECT 1 FROM WAVE(NOLOCK) WHERE Wavekey = @c_Wavekey)
               BEGIN
                  SELECT @b_success = 0
                  SELECT @c_Wavedetailkey = ''
                  EXECUTE nspg_GetKey
                     'WavedetailKey',
                     10,
                     @c_WaveDetailKey  OUTPUT,
                     @b_success     OUTPUT,
                     @n_err         OUTPUT,
                     @c_errmsg      OUTPUT
                  
                  IF @b_success <> 1
                  BEGIN
                    SELECT @n_continue = 3
                  END           
                  ELSE
                  BEGIN                                   
                     INSERT INTO WAVEDETAIL ( Wavedetailkey, Wavekey, Orderkey )
                                    VALUES  ( @c_Wavedetailkey, @c_Wavekey, @c_NewOrderkey)

  	   	             SELECT @n_err = @@ERROR
   	   	             IF @n_err <> 0
   	                 BEGIN
   		                 SELECT @n_continue = 3
			                 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36125
			                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert WaveDetail Table. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		                 END   
		              END         	                  
               END       	 	  
            END
       	 	         	 	  
            --Create new/Get pickslip if require and update to pickdetail
            IF @n_Continue IN(1,2)
            BEGIN
               SET @c_PickSlipno = ''      
               SELECT @c_PickSlipno = PickheaderKey  
               FROM PickHeader (NOLOCK)  
               WHERE ExternOrderkey = @c_NewLoadkey
               AND ISNULL(OrderKey,'') = ''
                             
               -- Create Pickheader      
               IF ISNULL(@c_PickSlipno ,'') = ''  
               BEGIN  
                  EXECUTE dbo.nspg_GetKey   
                  'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_Err OUTPUT,   @c_Errmsg OUTPUT      
               
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PICKSLIP) (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                     GOTO QUIT_SP
                  END
                    
                  SELECT @c_Pickslipno = 'P'+@c_Pickslipno      
                             
                  INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)  
                                  VALUES (@c_Pickslipno , @c_NewLoadKey, '', '0', 'LB', '')              
               
                  SET @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36031   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Pickheader Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                     GOTO QUIT_SP
                  END
               END
               
               --Update pickslip no to pickdetail of new order
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET    PickSlipNo = @c_PickSlipNo  
                     ,TrafficCop = NULL  
               FROM LOADPLANDETAIL (NOLOCK)
               JOIN PICKDETAIL ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey
               WHERE LOADPLANDETAIL.LoadKey = @c_NewLoadKey     
               AND LOADPLANDETAIL.Orderkey = @c_NewOrderkey
               
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                  GOTO QUIT_SP
               END                                    

               /*
               IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND Orderkey = @c_NewOrderkey)
               BEGIN
                  INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
                  SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
                  FROM PICKDETAIL (NOLOCK)  
                  WHERE PickSlipNo = @c_PickSlipNo  
                  AND Orderkey = @c_NewOrderkey
                  
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 360140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert RefkeyLookUp Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                     GOTO QUIT_SP
                  END   
               END
               */
            END
            
            --Create new pickinginfo if require 
            IF @n_Continue IN(1,2)
            BEGIN
               IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @c_Pickslipno) = 0
               BEGIN
                  SET @c_OldPickSlipno = ''      
                  SELECT @c_OldPickSlipno = PickheaderKey  
                  FROM PickHeader (NOLOCK)  
                  WHERE ExternOrderkey = @c_Loadkey
                  AND ISNULL(OrderKey,'') = ''
               	  
               	  IF ISNULL(@c_OldPickslipno,'') <> ''
               	  BEGIN
                     INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                     SELECT @c_PickslipNo, ScanInDate, PickerID, ScanOutDate
                     FROM PICKINGINFO (NOLOCK)
                     WHERE PickSlipNo = @c_OldPickSlipNo
                  END
                  ELSE
                  BEGIN
                     INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                     VALUES (@c_Pickslipno ,GETDATE(),sUser_sName(), GETDATE())
                  END
                  
                  SET @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickingInfo Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                     GOTO QUIT_SP
                  END
               END            	
            END

            --Create new packheader if require
            IF @n_Continue IN(1,2)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
	             BEGIN
                  INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, Status)      
                         SELECT TOP 1 O.Route, '', '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo, '9'       
                         FROM  PICKHEADER PH (NOLOCK)      
                         JOIN  Orders O (NOLOCK) ON (PH.ExternOrderkey = O.Loadkey)      
                         WHERE PH.PickHeaderKey = @c_PickSlipNo
                  
                  SET @n_err = @@ERROR
                  
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packheader Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                     GOTO QUIT_SP
                  END
	             END
            END
            
      	 	  --Move packdetail and packinfo to new pickslip(loadplan)
            IF @n_Continue IN(1,2)
            BEGIN
               DECLARE CUR_MOVECARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            	    SELECT DISTINCT PKD.Pickslipno, PKD.CartonNo, PKD.LabelNo, PKD.LabelLine
                  FROM #TMP_PICKDETAIL TP
                  JOIN PICKDETAIL PD (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey
                  JOIN PACKDETAIL PKD (NOLOCK) ON PD.CaseID = PKD.Labelno
                  WHERE TP.Orderkey = @c_Orderkey
                  AND PKD.Pickslipno <> @c_Pickslipno --case already move to new pack by previous order
                  ORDER BY PKD.Pickslipno, PKD.LabelNo, PKD.LabelLine

               OPEN CUR_MOVECARTON  
      
               FETCH NEXT FROM CUR_MOVECARTON INTO @c_MoveFromPickslipno, @n_MoveFromCartonNo, @c_MoveFromLabelNo, @c_MoveFromLabelLine
               
               SET @n_NewCartonno = 0
               SET @n_NewLabelLine = 0
               SET @c_NewLabelLine = ''
               SET @c_PrevMoveFromLabelNo = ''

               SELECT @n_NewCartonNo = MAX(CartonNo)
                      --@n_NewLabelLine = CAST(MAX(LabelLine) AS INT) 
               FROM PACKDETAIL (NOLOCK) 
               WHERE Pickslipno = @c_Pickslipno
               
               IF ISNULL(@n_NewCartonNo,0) = 0
                  SET @n_NewCartonNo = 0

               --IF ISNULL(@n_NewLabelLine,0) = 0
                  --SET @n_NewLabelLine = 0
               
               WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)
               BEGIN               	
               	  IF @c_PrevMoveFromLabelNo <> @c_MoveFromLabelNo 
               	  BEGIN
                  	  SET @n_NewCartonNo = @n_NewCartonNo +  1
                  	  SET @n_NewLabelLine = 0
                  	  
                  	  --Move packinfo to new pickslip
                  	  UPDATE PACKINFO WITH (ROWLOCK)
                  	  SET Pickslipno = @c_Pickslipno,
                  	      CartonNo = @n_NewCartonNo,
                  	      TrafficCop = NULL
                  	  WHERE Pickslipno = @c_MoveFromPickSlipNo
                  	  AND CartonNo = @n_MoveFromCartonNo

                      SET @n_err = @@ERROR
                      
                      IF @n_err <> 0
                      BEGIN
                         SELECT @n_continue = 3  
                         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PackInfo Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                      END
               	  END
               	  
               	  SET @n_NewLabelLine = @n_NewLabelLine + 1
               	  SET @c_NewLabelLine = RIGHT('00000' + RTRIM(LTRIM(CAST(@n_NewLabelLine AS NVARCHAR))),5)
               	
               	  UPDATE PACKDETAIL WITH (ROWLOCK)
               	  SET PickslipNo = @c_Pickslipno,
               	      CartonNo = @n_NewCartonNo,
               	      LabelLine = @c_NewLabelLine,
               	      Refno2 = RTRIM(@c_MoveFromPickslipno) +'-' +CAST(@n_MoveFromCartonNo AS NVARCHAR)
               	  WHERE Pickslipno = @c_MoveFromPickslipno
               	  AND LabelNo = @c_MoveFromLabelNo    
               	  AND LabelLine = @c_MoveFromLabelLine

                  SET @n_err = @@ERROR
                  
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PackDetail Table (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                  END
                  
                  SET @c_PrevMoveFromLabelNo = @c_MoveFromLabelNo
               	                 	  
                  FETCH NEXT FROM CUR_MOVECARTON INTO @c_MoveFromPickslipno, @n_MoveFromCartonNo, @c_MoveFromLabelNo, @c_MoveFromLabelLine
               END
               CLOSE CUR_MOVECARTON  
               DEALLOCATE CUR_MOVECARTON                                                 	                          	
            END
       	 	  	 	              	 	  
            SET @c_MBOLOrderkey = @c_NewOrderkey
            SET @c_MBOLLoadkey = @c_NewLoadkey
      	 END --end split order
      	 
      	 --Add order to MBOL
      	 IF NOT EXISTS (SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE MBOLKey = @c_MBOLKey AND Orderkey = @c_MBOLOrderkey)
      	 BEGIN
            EXEC isp_InsertMBOLDetail 
                 @c_MBOLKey,
                 @c_Facility,
                 @c_MBOLOrderKey,
                 @c_MBOLLoadKey,
                 @n_TotalGrossWgt,      
                 @n_TotalCube,         
                 @c_ExternOrderKey,   
                 @d_OrderDate,
                 @d_DeliveryDate, 
                 @c_Route, 
                 @b_Success OUTPUT, 
                 @n_err OUTPUT,
                 @c_errmsg OUTPUT         	 	
                 
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36190   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert MBOLDETAL Error. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP 
            END
         END
                               
         FETCH NEXT FROM CUR_CONTR_ORDER INTO @c_Orderkey, @c_Storerkey, @n_ContrQty, @n_OrderQty, @c_Facility, @c_Loadkey, @n_TotalCube,
                                              @n_TotalGrossWgt, @c_Route, @d_OrderDate, @d_DeliveryDate, @c_ExternOrderkey, @c_MBOLkeyFromOrder, @c_Wavekey
      END
      CLOSE CUR_CONTR_ORDER  
      DEALLOCATE CUR_CONTR_ORDER                                     
   END
   
   --Create Move Task
   /*
   IF @n_Continue IN(1,2)
   BEGIN      
      DECLARE CUR_CONTR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TP.Storerkey, PD.Loc, PD.ID, LOC.LogicalLocation, SUM(TP.ContrQty)
         FROM #TMP_PICKDETAIL TP (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         GROUP BY TP.Storerkey, PD.Loc, PD.ID, LOC.LogicalLocation
         
      OPEN CUR_CONTR_PALLET  
      
      FETCH NEXT FROM CUR_CONTR_PALLET INTO @c_Storerkey, @c_Loc, @c_ID, @c_LogicalLocation, @n_Qty

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	
         SELECT @b_success = 1  
         EXECUTE   nspg_getkey  
         "TaskDetailKey"  
         , 10  
         , @c_taskdetailkey OUTPUT  
         , @b_success OUTPUT  
         , @n_err OUTPUT  
         , @c_errmsg OUTPUT  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3              
         END  
         
         IF @b_success = 1  
         BEGIN      
           INSERT TASKDETAIL  
            (  
              TaskDetailKey  
             ,TaskType  
             ,Storerkey  
             ,Sku  
             ,UOM  
             ,UOMQty  
             ,Qty  
             ,SystemQty
             ,Lot  
             ,FromLoc  
             ,FromID  
             ,ToLoc  
             ,ToID  
             ,SourceType  
             ,SourceKey  
             ,Priority  
             ,SourcePriority  
             ,Status  
             ,LogicalFromLoc  
             ,LogicalToLoc  
             ,PickMethod
            )  
            VALUES  
            (  
              @c_taskdetailkey  
             ,'MVF' --Tasktype  
             ,@c_Storerkey  
             ,'' --Sku  
             ,'' --UOM,  
             ,0  --UOMQty,  
             ,@n_Qty  --Qty
             ,@n_Qty  --systemqty
             ,'' --Lot   
             ,@c_loc --from loc  
             ,@c_ID -- from id  
             ,@c_toloc --to loc
             ,@c_ID -- to id  
             ,'ispMBRTK05' --Sourcetype  
             ,@c_mbolkey --Sourcekey  
             ,'5' -- Priority  
             ,'9' -- Sourcepriority  
             ,'0' -- Status  
             ,@c_LogicalLocation --Logical from loc  
             ,@c_ToLogicalLocation --Logical to loc  
             ,'FP' --pickmethod
            )
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispMBRTK05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END            
         END
   
         FETCH NEXT FROM CUR_CONTR_PALLET INTO @c_Storerkey, @c_Loc, @c_ID, @c_LogicalLocation, @n_Qty
      END
      CLOSE CUR_CONTR_PALLET  
      DEALLOCATE CUR_CONTR_PALLET      
   END
   */                                                   
END

QUIT_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  ROLLBACK TRAN
 END
 ELSE
 BEGIN
  WHILE @@TRANCOUNT > @n_StartTranCnt
  BEGIN
   COMMIT TRAN
  END
 END
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK05'
 --RAISERROR @n_err @c_errmsg
 RETURN
END
ELSE
BEGIN
 SELECT @b_success = 1
 WHILE @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  COMMIT TRAN
 END
 RETURN
END

GO