SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_02               			  	      */
/* Creation Date: 28-Apr-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Vital - Muji Packing list                                   */
/* (SOS#134663)                                                         */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_02                          */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*	18Aug2009	 GTGOH	  1.1	  Include MBOL.UserDefine01 for Trade Term*/ 	
/*										  - SOS#142633									   */
/* 08-Sep-2009  Audrey    1.2   SOS#147321 Bug fix                      */    
/*                              - Sum(shipped qty) >0, rounding         */    
/*                                Netwgt,grosswgt to 3 decimal point    */   
/* 30-Sep-2009  SPChin    1.3   SOS#147312 - Use Round for Cube to 4    */
/*                                           decimal point              */ 
/* 09-Nov-2009  GTGoh     1.4   SOS#152658 - Add in statement if print  */
/*                                           from Container Manifest    */ 
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_02] (
  @cMBOL_ContrKey NVARCHAR(21)		--SOS#152658
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   
   CREATE TABLE #TEMP_PACK (
		MBOLKey			 NVARCHAR(20) NULL,
		VesselVoyage	 NVARCHAR(70) NULL,
		PlaceOfLoading	 NVARCHAR(30) NULL,
		PlaceOfDischarge NVARCHAR(30) NULL,	
		Equipment		 NVARCHAR(10) NULL,
		Containerno		 NVARCHAR(30) NULL,
		Sealno			 NVARCHAR(30) NULL,
		DepartureDate		datetime NULL,
		ArrivalDate			datetime NULL,
		BookingReference NVARCHAR(30) NULL,
		IDS_Company		 NVARCHAR(45) NULL,
		IDS_Address1	 NVARCHAR(45) NULL, 
		IDS_Address2	 NVARCHAR(45) NULL, 
		IDS_Address3	 NVARCHAR(45) NULL, 
		IDS_Address4	 NVARCHAR(45) NULL, 
		IDS_Phone1		 NVARCHAR(18) NULL, 
		IDS_Fax1			 NVARCHAR(18) NULL, 
		Billtokey		 NVARCHAR(15) NULL,
		BILLTO_Company	 NVARCHAR(45) NULL,
		BILLTO_Address1 NVARCHAR(45) NULL, 
		BILLTO_Address2 NVARCHAR(45) NULL, 
		BILLTO_Address3 NVARCHAR(45) NULL, 
		BILLTO_Address4 NVARCHAR(45) NULL, 
		BILLTO_City		 NVARCHAR(45) NULL, 
		BILLTO_Zip		 NVARCHAR(18) NULL, 
		BILLTO_Country	 NVARCHAR(30) NULL, 
		StorerKey		 NVARCHAR(15) NULL, 
		SKU				 NVARCHAR(20) NULL, 
		Descr				 NVARCHAR(91) NULL, 
		QtyShipped			int NULL, 
		Stdnetwgt			float NULL, 
		NetWgt				float NULL, 
		GrossWgt				float NULL, 
		UserDefine01	 NVARCHAR(20) NULL
		)

   CREATE TABLE #TEMP_PACKCTN (
      PickSlipNo   NVARCHAR(10) NULL,
      totalctn  INT      NULL
      )
   
	DECLARE @n_totalcarton int,
           @n_totalnetwgt float,
           @n_totalgrosswgt float,
           @n_totalcube float

	     
--	SOS#152658 Start
   DECLARE @c_refkey NVARCHAR(20),
           @n_pos INT,
           @c_rpttype NVARCHAR(10)
   
   SELECT @n_pos = CHARINDEX('$', @cMBOL_ContrKey, 0)
   
   IF @n_pos > 0 
   BEGIN   	  
      SELECT @c_refkey = LEFT(@cMBOL_ContrKey, @n_pos - 1)
      SELECT @c_rpttype = 'CONTAINER'
   END
   ELSE
   BEGIN
      SELECT @c_refkey = @cMBOL_ContrKey
      SELECT @c_rpttype = 'MBOL'   	  
   END
--	SOS#152658 End

--	SOS#152658 Start
	IF @c_rpttype = 'CONTAINER'
	BEGIN 
		INSERT INTO #TEMP_PACK
	 	SELECT Container.OtherReference,
   					ISNULL(RTRIM(Container.Vessel),'') + ' / ' + ISNULL(RTRIM(Container.Voyage),'') AS VesselVoyage,
						MBOL.PlaceOfLoading,
   					MBOL.PlaceOfDischarge,
   					Container.ContainerType,
   					Container.BookingReference,
   					Container.Seal01,
   					MBOL.DepartureDate,
   					MBOL.ArrivalDate,
   					MBOL.BookingReference,
   					IDSCNSZ.Company AS IDS_Company,
   					IDSCNSZ.Address1 AS IDS_Address1,
   					IDSCNSZ.Address2 AS IDS_Address2,
   					IDSCNSZ.Address3 AS IDS_Address3,
   					IDSCNSZ.Address4 AS IDS_Address4,
   					IDSCNSZ.Phone1 AS IDS_Phone1,
   					IDSCNSZ.Fax1 AS IDS_Fax1,
						BILLTO.Storerkey AS Billtokey,
   					BILLTO.Company AS BILLTO_Company,
   					BILLTO.Address1 AS BILLTO_Address1,
   					BILLTO.Address2 AS BILLTO_Address2,
   					BILLTO.Address3 AS BILLTO_Address3,
   					BILLTO.Address4 AS BILLTO_Address4,
   					BILLTO.City AS BILLTO_City,
   					BILLTO.Zip AS BILLTO_Zip,
   					BILLTO.Country AS BILLTO_Country,
   					ORDERS.StorerKey,
   					PACKDETAIL.SKU,
   					RTRIM(SKU.Descr)+' '+RTRIM(ISNULL(SKU.Busr1,'')) AS Descr,
   					SUM(PACKDETAIL.Qty)AS QtyShipped,
   					round(SKU.Stdnetwgt,3) as Stdnetwgt,
   					SUM(PACKDETAIL.Qty) * round(SKU.Stdnetwgt,3) AS NetWgt, 
   					SUM(PACKDETAIL.Qty)* round(SKU.StdGrosswgt,3) AS GrossWgt
						,MBOL.UserDefine01	
   	FROM MBOL WITH (NOLOCK)
   				INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   				INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
--   				INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
			      INNER JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = 'MGS')
   				INNER JOIN STORER BILLTO WITH (NOLOCK) ON (MBOL.CONSIGNEEACCOUNTCODE = BILLTO.Storerkey)
					INNER JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey 
                                              AND ORDERS.Loadkey = PACKHEADER.Loadkey)
					INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)
   				INNER JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.StorerKey = SKU.StorerKey AND PACKDETAIL.Sku = SKU.Sku)
   				INNER JOIN CONTAINER WITH (NOLOCK) ON (MBOL.Mbolkey = CONTAINER.OtherReference)
					INNER JOIN CONTAINERDETAIL WITH (NOLOCK) ON (CONTAINER.Containerkey = CONTAINERDETAIL.Containerkey
                          AND PACKDETAIL.LabelNo = CONTAINERDETAIL.Palletkey)
		WHERE CONTAINER.ContainerKey = @c_refkey
		GROUP BY Container.OtherReference,
   					Container.Vessel,
						Container.Voyage,
						MBOL.PlaceOfLoading,
   					MBOL.PlaceOfDischarge,
   					Container.ContainerType,
   					Container.BookingReference,
   					Container.Seal01,
   					MBOL.DepartureDate,
   					MBOL.ArrivalDate,
   					MBOL.BookingReference,
   					IDSCNSZ.Company,
   					IDSCNSZ.Address1,
   					IDSCNSZ.Address2,
   					IDSCNSZ.Address3,
   					IDSCNSZ.Address4,
   					IDSCNSZ.Phone1,
   					IDSCNSZ.Fax1,
						BILLTO.Storerkey,
   					BILLTO.Company,
   					BILLTO.Address1,
   					BILLTO.Address2,
   					BILLTO.Address3,
   					BILLTO.Address4,
   					BILLTO.City,
   					BILLTO.Zip,
   					BILLTO.Country,
   					ORDERS.StorerKey,
   					PACKDETAIL.SKU,
   					SKU.Descr,
   					SKU.Busr1,
   					SKU.Stdnetwgt,
   					SKU.StdGrosswgt
						,MBOL.UserDefine01	--SOS#142633
						Having SUM(PACKDETAIL.Qty) > 0 --SOS#147321  


      
		INSERT INTO #TEMP_PACKCTN
		SELECT PACKHEADER.PickSlipNo, COUNT(DISTINCT CONTAINERDETAIL.Palletkey)
      FROM MBOL WITH (NOLOCK)
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      INNER JOIN PACKHEADER WITH (NOLOCK) ON ( PACKHEADER.Orderkey = ORDERS.Orderkey AND
         										        PACKHEADER.Loadkey = ORDERS.Loadkey )
      INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)      										   
      INNER JOIN CONTAINER WITH (NOLOCK) ON (MBOL.Mbolkey = CONTAINER.OtherReference)
      INNER JOIN CONTAINERDETAIL WITH (NOLOCK) ON (CONTAINER.Containerkey = CONTAINERDETAIL.Containerkey
                                                   AND PACKDETAIL.LabelNo = CONTAINERDETAIL.Palletkey)
      WHERE CONTAINER.Containerkey = @c_refkey 
      GROUP BY PACKHEADER.PickSlipNo
   
		
		SELECT DISTINCT PACKHEADER.Pickslipno, PACKDETAIL.CartonNo
   	  INTO #TMP_CTN
      FROM MBOL WITH (NOLOCK)
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      INNER JOIN PACKHEADER WITH (NOLOCK) ON ( PACKHEADER.Orderkey = ORDERS.Orderkey AND
         										        PACKHEADER.Loadkey = ORDERS.Loadkey )
      INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)      										   
      INNER JOIN CONTAINER WITH (NOLOCK) ON (MBOL.Mbolkey = CONTAINER.OtherReference)
      INNER JOIN CONTAINERDETAIL WITH (NOLOCK) ON (CONTAINER.Containerkey = CONTAINERDETAIL.Containerkey
                                                   AND PACKDETAIL.LabelNo = CONTAINERDETAIL.Palletkey)
      WHERE CONTAINER.Containerkey = @c_refkey
   	  
   	  
      SELECT @n_TotalCube = ROUND(SUM(PACKINFO.Cube),4)  --SOS#147312  
      FROM PACKINFO WITH (NOLOCK) 
      INNER JOIN #TMP_CTN ON (PACKINFO.Pickslipno = #TMP_CTN.Pickslipno AND PACKINFO.Cartonno = #TMP_CTN.Cartonno)
   
	END
	ELSE
	BEGIN
		INSERT INTO #TEMP_PACK
		SELECT MBOL.MBOLKey,
   					ISNULL(RTRIM(MBOL.OtherReference),'') + ' / ' + ISNULL(RTRIM(MBOL.VoyageNumber),'') AS VesselVoyage,
   					MBOL.PlaceOfLoading,
   					MBOL.PlaceOfDischarge,
   					MBOL.Equipment,
   					MBOL.Containerno,
   					MBOL.Sealno,
   					MBOL.DepartureDate,
   					MBOL.ArrivalDate,
   					MBOL.BookingReference,
   					IDSCNSZ.Company AS IDS_Company,
   					IDSCNSZ.Address1 AS IDS_Address1,
   					IDSCNSZ.Address2 AS IDS_Address2,
   					IDSCNSZ.Address3 AS IDS_Address3,
   					IDSCNSZ.Address4 AS IDS_Address4,
   					IDSCNSZ.Phone1 AS IDS_Phone1,
   					IDSCNSZ.Fax1 AS IDS_Fax1,
						BILLTO.Storerkey AS Billtokey,
   					BILLTO.Company AS BILLTO_Company,
   					BILLTO.Address1 AS BILLTO_Address1,
   					BILLTO.Address2 AS BILLTO_Address2,
   					BILLTO.Address3 AS BILLTO_Address3,
   					BILLTO.Address4 AS BILLTO_Address4,
   					BILLTO.City AS BILLTO_City,
   					BILLTO.Zip AS BILLTO_Zip,
   					BILLTO.Country AS BILLTO_Country,
   					ORDERDETAIL.StorerKey,
   					ORDERDETAIL.SKU,
   					RTRIM(SKU.Descr)+' '+RTRIM(ISNULL(SKU.Busr1,'')) AS Descr,
   					SUM(ORDERDETAIL.qtypicked+ORDERDETAIL.shippedqty)AS QtyShipped,
   					round(SKU.Stdnetwgt,3) as Stdnetwgt,--SOS#147321
   					SUM(ORDERDETAIL.qtypicked+ORDERDETAIL.shippedqty) * round(SKU.Stdnetwgt,3) AS NetWgt, --SOS#147321
   					SUM(ORDERDETAIL.qtypicked+ORDERDETAIL.shippedqty)* round(SKU.StdGrosswgt,3) AS GrossWgt --SOS#147321
						,MBOL.UserDefine01	--SOS#142633
		FROM MBOL WITH (NOLOCK)
   				INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   				INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   				INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   				INNER JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku)
   				INNER JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = 'MGS')	--SOS#142633
   				INNER JOIN STORER BILLTO WITH (NOLOCK) ON (MBOL.CONSIGNEEACCOUNTCODE = BILLTO.Storerkey)
		WHERE MBOL.MBOLKey = @c_refkey
		GROUP BY MBOL.MBOLKey,
   					MBOL.OtherReference,
   					MBOL.VoyageNumber,
   					MBOL.PlaceOfLoading,
   					MBOL.PlaceOfDischarge,
   					MBOL.Equipment,
   					MBOL.Containerno,
   					MBOL.Sealno,
   					MBOL.DepartureDate,
   					MBOL.ArrivalDate,
   					MBOL.BookingReference,
   					IDSCNSZ.Company,
   					IDSCNSZ.Address1,
   					IDSCNSZ.Address2,
   					IDSCNSZ.Address3,
   					IDSCNSZ.Address4,
   					IDSCNSZ.Phone1,
   					IDSCNSZ.Fax1,
						BILLTO.Storerkey,
   					BILLTO.Company,
   					BILLTO.Address1,
   					BILLTO.Address2,
   					BILLTO.Address3,
   					BILLTO.Address4,
   					BILLTO.City,
   					BILLTO.Zip,
   					BILLTO.Country,
   					ORDERDETAIL.StorerKey,
   					ORDERDETAIL.SKU,
   					SKU.Descr,
   					SKU.Busr1,
   					SKU.Stdnetwgt,
   					SKU.StdGrosswgt
						,MBOL.UserDefine01	--SOS#142633
						Having SUM(ORDERDETAIL.qtypicked+ORDERDETAIL.shippedqty) > 0 --SOS#147321  


		INSERT INTO #TEMP_PACKCTN
		SELECT PACKHEADER.PickSlipNo, COUNT(DISTINCT PACKDETAIL.CartonNo)
		FROM MBOLDETAIL WITH (NOLOCK)
		INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
		INNER JOIN PACKHEADER WITH (NOLOCK) ON ( PACKHEADER.Orderkey = ORDERS.Orderkey AND
														PACKHEADER.Loadkey = ORDERS.Loadkey )      										   
		INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)      										   
		WHERE MBOLDETAIL.MBOLKey = @cMBOL_ContrKey
		GROUP BY PACKHEADER.PickSlipNo

		--SELECT @n_TotalCube = SUM(PACKINFO.Cube)           --SOS#147312
		SELECT @n_TotalCube = ROUND(SUM(PACKINFO.Cube),4)    --SOS#147312 
		FROM PACKINFO WITH (NOLOCK) 
		WHERE PACKINFO.PickSlipNo IN (SELECT PickSlipNo FROM #TEMP_PACKCTN)

	END
	--	SOS#152658 End
   
   
	SELECT @n_totalnetwgt = SUM(#TEMP_PACK.netwgt), 
			 @n_totalgrosswgt = SUM(#TEMP_PACK.grosswgt)
	FROM #TEMP_PACK     

	SELECT @n_TotalCarton = SUM(totalctn)
	FROM #TEMP_PACKCTN   
   

   SELECT MBOLKey,
   				VesselVoyage,
   				PlaceOfLoading,
   				PlaceOfDischarge,
   				Equipment,
   				Containerno,
   				Sealno,
   				DepartureDate,
   				ArrivalDate,
   				BookingReference,
   				IDS_Company,
   				IDS_Address1,
   				IDS_Address2,
   				IDS_Address3,
   				IDS_Address4,
   				IDS_Phone1,
   				IDS_Fax1,
               Billtokey,
   				BILLTO_Company,
   				BILLTO_Address1,
   				BILLTO_Address2,
   				BILLTO_Address3,
   				BILLTO_Address4,
   				BILLTO_City,
   				BILLTO_Zip,
   				BILLTO_Country,
   				StorerKey,
   				SKU,
   				Descr,
   				QtyShipped,
   				Stdnetwgt,
   				@n_TotalCarton,
   				@n_TotalNetWgt,
   				@n_TotalGrossWgt,
   				@n_TotalCube
					,UserDefine01	--SOS#142633
   FROM #TEMP_PACK
   ORDER BY sku

END

GO