SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispGenCartonLabel : 
--

/************************************************************************/
/* Store Procedure:  ispGenCartonLabel                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Generate Carton Label.                                     */
/*                                                                      */
/* Input Parameters:  @cLoadKey    - (Loadkey)                          */
/*                    @cDBName     - (Exceed DB Name)                   */
/*                    @cUserId     - (User ID)                          */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 13-Jun-2005  ONG       NSC Wave II Project Change Request            */ 
/*                        - (SOS#35110).                                */
/* 11-Jul-2005  YokeBeen  NSC Wave II Project Change Request            */ 
/*                        - (SOS#37943) (YokeBeen01).                   */
/* 29-Jul-2005  ONG02     NSC Wave II Project Change Request            */ 
/*                        - (SOS#38357).                                */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispGenCartonLabel] 
		@cLoadKey      NVARCHAR(10),
		@cDBName       NVARCHAR(20), 
		@cUserId       NVARCHAR(20) 
AS
	DECLARE @cExternOrderKey  NVARCHAR(50),   --tlting_ext
           @cOrderKey        NVARCHAR(10),
           @cCompany         NVARCHAR(60),
           @nCartonNo        int, 
           @nTotalCarton     int,
           @cBarCode         NVARCHAR(20),
           @cStop            NVARCHAR(20),
           @cDeliveryPlace   NVARCHAR(45),
           @cAddress         NVARCHAR(124), 
           @cPhone           NVARCHAR(20), 
           @cInvoiceNo       NVARCHAR(20),
           @cSeqNo           NVARCHAR(30),
           @PickSlipNo       NVARCHAR(10),
           @cDeliveryDate    NVARCHAR(10)

   SET NOCOUNT ON
   DECLARE Cur1 Scroll Cursor FOR
/* DISCRETE: PH.Orderkey <> '' Then (O.OrderKey = PH.OrderKey)  */
   SELECT O.ExternOrderkey, OD.OrderKey, 
          ISNULL(O.C_Company, ''),        
          CASE cast(PH.consigneekey as int) -- BEGIN (ONG02)
          	 WHEN 0     THEN 'd d'
         	 ELSE 'd' +RIGHT ( REPLICATE ('0', 10)+ dbo.fnc_LTRIM( dbo.fnc_RTRIM( STR( CAST(PH.consigneekey as int)))),10) + 'd'
          END,                                         -- END (ONG02)
--           'd' +RIGHT ( REPLICATE ('0', 10)+ dbo.fnc_LTRIM( dbo.fnc_RTRIM( STR( CAST(PH.consigneekey as int)))),10) + 'd',  -- O.OrderGroup,  -- modified by Ong sos 35110 050608
          CEILING(CONVERT(DECIMAL(8,2), SUM((OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / P.CaseCnt))),
          O.route,                    --   O.Stop, -- modified by Ong sos 35110
          ISNULL(O.DeliveryPlace, ''), 
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '')+' '+ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),    -- modified by Ong sos 35110
          ISNULL(O.C_City, ''),                                  --   O.C_Phone1, -- modified by Ong sos 35110
          '',                                                    --   O.InvoiceNo,-- modified by Ong sos 35110
          LD.LoadLineNumber,                                     --   O.B_Contact2,-- modified by Ong sos 35110 13Jun2005
          PH.PickHeaderKey,
          CONVERT(char(10), L.lpuserdefdate01, 111) -- CONVERT(char(10), O.userdefine06, 111)
   FROM IDSTW..ORDERS O (NOLOCK)
   JOIN IDSTW..ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
   JOIN IDSTW..PACK P (NOLOCK) ON (P.PackKey = OD.PackKey) 
   JOIN IDSTW..PICKHEADER PH (NOLOCK) ON (OD.OrderKey = PH.OrderKey) ---- modified by Ong sos 35110
   JOIN IDSTW..LOADPLANDETAIL LD (NOLOCK) on (OD.Orderkey = LD.Orderkey AND OD.Loadkey = LD.Loadkey) -- modified by Ong sos 35110 14Jun2005
   JOIN IDSTW..LOADPLAN L (NOLOCK) ON (L.Loadkey = OD.Loadkey) -- AND L.OrderKey = OD.OrderKey)
   WHERE PH.Externorderkey = @cLoadKey
	AND	PH.Orderkey <> ''
   AND   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0 
   AND   P.CaseCnt > 0 
   GROUP BY O.ExternOrderkey, OD.OrderKey, ISNULL(O.C_Company, ''), 
          PH.consigneekey, O.route, 
          ISNULL(O.DeliveryPlace, ''), 
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '') + ' ' + ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),
          ISNULL(O.C_City, ''), 
          LD.LoadLineNumber, 
          PH.PickHeaderKey,
          CONVERT(char(10), L.lpuserdefdate01, 111) -- CONVERT(char(10), O.userdefine06, 111)
	UNION   
   SELECT ' ' As ExternOrderKey,' ' As OrderKey,--O.ExternOrderkey, O.OrderKey, 
          ISNULL(O.C_Company, ''),      
          CASE cast(PH.consigneekey as int) -- BEGIN (ONG02)
          	 WHEN 0     THEN 'd d'
         	 ELSE 'd' +RIGHT ( REPLICATE ('0', 10)+ dbo.fnc_LTRIM( dbo.fnc_RTRIM( STR( CAST(PH.consigneekey as int)))),10) + 'd'
          END,                                         -- END (ONG02)
--           'd' +RIGHT ( REPLICATE ('0', 10)+ dbo.fnc_LTRIM( dbo.fnc_RTRIM( STR( CAST(PH.consigneekey as int)))),10) + 'd',
          CEILING(CONVERT(DECIMAL(8,2), SUM((OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / P.CaseCnt))),
          O.route,                 
          ISNULL(O.DeliveryPlace, ''), 
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '') + ' ' + ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),  --  -- modified by Ong sos 35110
          ISNULL(O.C_City, ''),        
          '',              
          '1',--SeqNo for conso
          PH.PickHeaderKey,
          CONVERT(char(10), L.lpuserdefdate01, 111) -- CONVERT(char(10), O.userdefine06, 111)
   FROM IDSTW..ORDERS O (NOLOCK)
   JOIN IDSTW..ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
   JOIN IDSTW..PACK P (NOLOCK) ON (P.PackKey = OD.PackKey) 
   JOIN IDSTW..PICKHEADER PH (NOLOCK) ON (OD.Loadkey = PH.ExternOrderkey) ---- modified by Ong sos 35110
   JOIN IDSTW..LOADPLAN L (NOLOCK) ON (L.Loadkey = OD.Loadkey) -- AND L.OrderKey = OD.OrderKey)
   WHERE PH.Externorderkey = @cLoadKey
	AND	PH.Orderkey = ''
   AND   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0 
   AND   P.CaseCnt > 0 
   GROUP BY ISNULL(O.C_Company, ''),    --O.ExternOrderkey, O.OrderKey, 
          PH.consigneekey, O.route, 
          ISNULL(O.DeliveryPlace, ''), 
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '') + ' ' + ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),
          ISNULL(O.C_City, ''),               
          PH.PickHeaderKey,  
          CONVERT(char(10), L.lpuserdefdate01, 111)
	ORDER BY PH.PickHeaderKey  -- (YokeBeen01)


	IF @cUserId = 'NIKE01'
	BEGIN
	   OPEN Cur1	   
      
	   FETCH NEXT FROM Cur1 INTO @cExternOrderKey, @cOrderKey, @cCompany, @cBarCode,  @nTotalCarton, @cStop, 
	                             @cDeliveryPlace, @cAddress, @cPhone, @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate 
		WHILE @@Fetch_Status <> -1
		BEGIN
         IF @nTotalCarton = 0 
            SELECT @nTotalCarton = 1
			SELECT @nCartonNo = 1 
			While @nCartonNo <= @nTotalCarton
			BEGIN
				INSERT INTO CartonLabel1 (ExternOrderKey, OrderKey, LoadKey, Company, Barcode, UserId, CartonNo, TotalCarton, 
				                  DepotNo, DepotName, DeliverAddr, ContactNo, NikePickSlipNo, SeqNo, PickSlipNo, DeliveryDate)
				VALUES (@cExternOrderKey, @cOrderKey, @cLoadKey, @cCompany, @cBarcode, @cUserid, @nCartonNo, @nTotalCarton, 
						  @cStop, @cDeliveryPlace, @cAddress, ISNULL(@cPhone, ''), @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate)		
				SELECT @nCartonNo = @nCartonNo + 1
			END
   			FETCH NEXT FROM Cur1 INTO @cExternOrderKey, @cOrderKey, @cCompany, @cBarCode,  @nTotalCarton, @cStop, 
   			           @cDeliveryPlace, @cAddress, @cPhone, @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate 
		END 
	END
	ELSE
		IF @cUserId = 'NIKE02'
		BEGIN
		   OPEN Cur1

		   FETCH NEXT FROM Cur1 INTO @cExternOrderKey, @cOrderKey, @cCompany, @cBarCode,  @nTotalCarton, @cStop, 
		                             @cDeliveryPlace, @cAddress, @cPhone, @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate 
			WHILE @@Fetch_Status <> -1
			BEGIN
            IF @nTotalCarton = 0 
               SELECT @nTotalCarton = 1
				SELECT @nCartonNo = 1 
				While @nCartonNo <= @nTotalCarton
				BEGIN
					INSERT INTO CartonLabel2 (ExternOrderKey, OrderKey, LoadKey, Company, Barcode, UserId, CartonNo, TotalCarton, 
					                  DepotNo, DepotName, DeliverAddr, ContactNo, NikePickSlipNo, SeqNo, PickSlipNo, DeliveryDate)
					VALUES (@cExternOrderKey, @cOrderKey, @cLoadKey, @cCompany, @cBarcode, @cUserid, @nCartonNo, @nTotalCarton, 
							  @cStop, @cDeliveryPlace, @cAddress, ISNULL(@cPhone, ''), @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate)			
					SELECT @nCartonNo = @nCartonNo + 1
				END

				FETCH NEXT FROM Cur1 INTO @cExternOrderKey, @cOrderKey, @cCompany, @cBarCode,  @nTotalCarton, @cStop, 
				                     @cDeliveryPlace, @cAddress, @cPhone, @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate 
			END 
		END

   CLOSE Cur1
   DEALLOCATE Cur1

--    select * FROM CartonLabel1   -- for testing purpose
--    select * FROM CartonLabel2   -- for testing purpose

GO