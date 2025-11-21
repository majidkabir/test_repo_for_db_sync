SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Delivery_Note25                                     */
/* Creation Date: 16-JAN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-3760  [TW] CJBST Delivery Note                         */
/*        :                                                             */
/* Called By: r_dw_delivery_note25                                      */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 12-Feb-2018  SPChin    1.1 INC0119082 - Bug Fixed                    */
/************************************************************************/
CREATE PROC [dbo].[isp_Delivery_Note25] 
            @c_LoadKey  NVARCHAR(10)       = ''
           ,@c_startorderkey  NVARCHAR(10) = ''
           ,@c_EndOrderkey   NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_getconsignee    NVARCHAR(100)
         , @c_facility        NVARCHAR(20)
         , @c_GetCAdd         NVARCHAR(120)
         , @c_storerkey       NVARCHAR(10)
         , @c_orderkey        NVARCHAR(10)
         , @c_getcompany      NVARCHAR(45)
         , @c_printbyload     NVARCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_printbyload = 'Y'

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TEMP_DELNOTE25
      (  RowRef               INT IDENTITY(1,1)
      ,  loadKey              NVARCHAR(10)
      ,  DELDate              DATETIME
      ,  BuyerPO              NVARCHAR(30)
      ,  consigneeAdd         NVARCHAR(120)
      ,  Facility             NVARCHAR(5)
      ,  Orderkey             NVARCHAR(10)
      ,  Consigneekey         NVARCHAR(45)
      ,  C_Company            NVARCHAR(45)
      ,  C_Address1           NVARCHAR(45)
      ,  ST_Company           NVARCHAR(45)
      ,  notes                NVARCHAR(4000)
      ,  Storerkey            NVARCHAR(15)
      ,  Sku                  NVARCHAR(20)
      ,  SkuDescr             NVARCHAR(60)
      ,  Qty                  INT
      ,  UOM                  NVARCHAR(10)
      ,  Pallet               FLOAT
      ,  c_phone1             NVARCHAR(30)
      ,  OrdDate              DATETIME
      )


		IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
		           WHERE Orderkey = @c_startorderkey)
		BEGIN
			SET @c_printbyload = 'N'
		END        
		   
   IF @c_printbyload = 'Y'
   BEGIN
			INSERT INTO #TEMP_DELNOTE25
			(
					Loadkey              
				,  DELDate             
				,  BuyerPO               
				,  consigneeAdd                
				,  Facility     
				,  orderkey              
				,  Consigneekey         
				,  C_Company            
				,  C_Address1                         
				,  Notes                    
				,  ST_Company                  
				,  Storerkey            
				,  Sku                  
				,  SkuDescr             
				,  Qty           
				,  UOM                  
				,  Pallet
				,c_phone1, OrdDate
			)
			SELECT DISTINCT
					 LPD.LoadKey
					,ORDERS.DeliveryDate
					,ORDERS.BuyerPO
					,consigneeAdd     = ''
					,Facility         = ISNULL(RTRIM(ORDERS.Facility),'')
					,ORDERS.Orderkey
					,Consigneekey     = ''
					,C_Company     = ISNULL(RTRIM(ORDERS.C_Company),'')     
					,C_Address1    = ISNULL(RTRIM(ORDERS.C_Address1),'')   
					,Notes          = ISNULL(RTRIM(ORDERS.Notes),'')
					,ST_Storerkey   = ISNULL(RTRIM(STORER.Storerkey),'')  
					,ORDERDETAIL.Storerkey
					,ORDERDETAIL.Sku 
					,SkuDescr       = ISNULL(RTRIM(SKU.Descr),'') 
					--,Qty            = SUM(ORDERDETAIL.ShippedQty+ORDERDETAIL.QtyAllocated+ORDERDETAIL.QtyPicked)				--INC0119082
					,Qty            = SUM(ORDERDETAIL.ShippedQty+ORDERDETAIL.QtyAllocated+ORDERDETAIL.QtyPicked)/P.CaseCnt	--INC0119082
					,UOM            = ISNULL(RTRIM(ORDERDETAIL.UOM ),'')
					,Pallet         = P.Pallet       
					,c_phone1       = ISNULL(ORDERS.c_phone1,'')
					,Orddate        = ORDERS.Orderdate
			FROM LOADPLANDETAIL LPD        WITH (NOLOCK)
			--JOIN ORDERS      WITH (NOLOCK) ON (LPD.LoadKey = ORDERS.LoadKey)															--INC0119082
			JOIN ORDERS      WITH (NOLOCK) ON (LPD.LoadKey = ORDERS.LoadKey AND LPD.Orderkey = ORDERS.Orderkey)				--INC0119082
			JOIN STORER      WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
			JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
			JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
													 AND(ORDERDETAIL.Sku = SKU.Sku)    
			JOIN PACK P WITH (NOLOCK) ON P.packkey=sku.PACKKey                                                         
			WHERE LPD.LoadKey = @c_LoadKey
			GROUP BY LPD.LoadKey
					,ORDERS.DeliveryDate
					,ORDERS.BuyerPO
					,ISNULL(RTRIM(ORDERS.Facility),'')
					,ORDERS.Orderkey
					,ISNULL(RTRIM(ORDERS.C_Company),'')     
					,ISNULL(RTRIM(ORDERS.C_Address1),'')   
					,ISNULL(RTRIM(ORDERS.Notes),'')
					,ISNULL(RTRIM(STORER.Storerkey),'')  
					,ORDERDETAIL.Storerkey
					,ORDERDETAIL.Sku 
					,ISNULL(RTRIM(SKU.Descr),'') 
					,ISNULL(RTRIM(ORDERDETAIL.UOM ),'')
					,P.Pallet ,ISNULL(ORDERS.c_phone1,''), ORDERS.Orderdate, P.CaseCnt 													--INC0119082  
			ORDER BY LPD.LoadKey,ORDERS.Orderkey
   END
   ELSE
   BEGIN
   	INSERT INTO #TEMP_DELNOTE25
			(
					Loadkey              
				,  DELDate             
				,  BuyerPO               
				,  consigneeAdd                
				,  Facility     
				,  orderkey              
				,  Consigneekey         
				,  C_Company            
				,  C_Address1                         
				,  Notes                    
				,  ST_Company                  
				,  Storerkey            
				,  Sku                  
				,  SkuDescr             
				,  Qty           
				,  UOM                  
				,  Pallet
				,c_phone1, OrdDate
			)
			SELECT DISTINCT
					 LPD.LoadKey
					,ORDERS.DeliveryDate
					,ORDERS.BuyerPO
					,consigneeAdd     = ''
					,Facility         = ISNULL(RTRIM(ORDERS.Facility),'')
					,ORDERS.Orderkey
					,Consigneekey     = ''
					,C_Company     = ISNULL(RTRIM(ORDERS.C_Company),'')     
					,C_Address1    = ISNULL(RTRIM(ORDERS.C_Address1),'')   
					,Notes          = ISNULL(RTRIM(ORDERS.Notes),'')
					,ST_Storerkey   = ISNULL(RTRIM(STORER.Storerkey),'')  
					,ORDERDETAIL.Storerkey
					,ORDERDETAIL.Sku 
					,SkuDescr       = ISNULL(RTRIM(SKU.Descr),'') 
					--,Qty            = SUM(ORDERDETAIL.ShippedQty+ORDERDETAIL.QtyAllocated+ORDERDETAIL.QtyPicked)				--INC0119082
					,Qty            = SUM(ORDERDETAIL.ShippedQty+ORDERDETAIL.QtyAllocated+ORDERDETAIL.QtyPicked)/P.CaseCnt	--INC0119082
					,UOM            = ISNULL(RTRIM(ORDERDETAIL.UOM ),'')
					,Pallet         = P.Pallet       
					,c_phone1       = ISNULL(ORDERS.c_phone1,'')
					,Orddate        = ORDERS.Orderdate 
			FROM LOADPLANDETAIL LPD        WITH (NOLOCK)
			--JOIN ORDERS      WITH (NOLOCK) ON (LPD.LoadKey = ORDERS.LoadKey)															--INC0119082
			JOIN ORDERS      WITH (NOLOCK) ON (LPD.LoadKey = ORDERS.LoadKey AND LPD.Orderkey = ORDERS.Orderkey)				--INC0119082
			JOIN STORER      WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
			JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
			JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
													 AND(ORDERDETAIL.Sku = SKU.Sku)    
			JOIN PACK P WITH (NOLOCK) ON P.packkey=sku.PACKKey                                                         
			WHERE ORDERS.orderkey BETWEEN @c_startorderkey AND @c_EndOrderkey
			GROUP BY LPD.LoadKey
					,ORDERS.DeliveryDate
					,ORDERS.BuyerPO
					,ISNULL(RTRIM(ORDERS.Facility),'')
					,ORDERS.Orderkey
					,ISNULL(RTRIM(ORDERS.C_Company),'')     
					,ISNULL(RTRIM(ORDERS.C_Address1),'')   
					,ISNULL(RTRIM(ORDERS.Notes),'')
					,ISNULL(RTRIM(STORER.Storerkey),'')  
					,ORDERDETAIL.Storerkey
					,ORDERDETAIL.Sku 
					,ISNULL(RTRIM(SKU.Descr),'') 
					,ISNULL(RTRIM(ORDERDETAIL.UOM ),'')
					,P.Pallet ,ISNULL(ORDERS.c_phone1,''), ORDERS.Orderdate,P.CaseCnt 													--INC0119082         
			ORDER BY LPD.LoadKey,ORDERS.Orderkey
   END	
   
      
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Orderkey,storerkey,facility   
   FROM   #TEMP_DELNOTE25   
   WHERE loadkey  =@c_LoadKey
   ORDER BY Orderkey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_orderkey,@c_storerkey,@c_facility    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

	SET @c_getconsignee = ''
	SET @c_GetCAdd = ''
	SET @c_getcompany = ''
	
	SELECT TOP 1 @c_getconsignee = OD.UserDefine01
	FROM ORDERDETAIL OD WITH (NOLOCK) 
	WHERE  OD.StorerKey = @c_storerkey
	AND OD.orderkey = @c_orderkey


	IF ISNULL(@c_getconsignee,'') = ''
	BEGIN
		SELECT @c_getcompany = DESCR
		       ,@c_GetCAdd = (city + SPACE(1) + address2)
		FROM FACILITY WITH (NOLOCK)
		WHERE Facility = @c_facility
	END
	ELSE
	BEGIN
		SELECT @c_getcompany = S.company
		      ,@c_GetCAdd = (s.city + SPACE(1) + s.address2)
		FROM Storer S (NOLOCK)
		WHERE s.StorerKey = @c_getconsignee
	END	
	
	
	UPDATE #TEMP_DELNOTE25
	SET
		consigneeAdd = @c_GetCAdd,
		Consigneekey = @c_getcompany
	WHERE loadKey   = @c_LoadKey
	AND Orderkey    = @c_orderkey
	AND storerkey   = @c_storerkey

   FETCH NEXT FROM CUR_RESULT INTO  @c_orderkey,@c_storerkey,@c_facility    
   END   

QUIT_SP:
   SELECT Loadkey   
      ,  orderkey        
      ,  Notes   
      ,  Consigneekey         
      ,  C_Company     
      ,  C_Address1    
      ,  DELDate             
      ,  BuyerPO               
      ,  consigneeAdd 
      ,  SkuDescr               
      ,  Facility  
      ,  Qty           
      ,  UOM         
      ,  Storerkey              
      ,  Sku            
      ,  ST_Company                      
      ,  Pallet
      ,c_phone1,OrdDate
   FROM #TEMP_DELNOTE25 AS td
   ORDER BY loadkey,orderkey

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO