SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispGenManifestSummarySerialReport                  */
/* Creation Date:  29-Jul-2008                                          */
/* Copyright: IDS                                                       */
/* Written by:  Shong                                                   */
/*                                                                      */
/* Purpose:  Delivery Note/Despatch Manifest Summary                    */
/*                                                                      */
/* Input Parameters:  @c_MbolKey  - (MBOLKey)                           */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  r_dw_manifest_summary_serial                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 17-Sep-2013  YTWan    1.1  FBR288717- Default Remark on Manifest Rpt */
/*                            (Wan01)                                   */
/* 03-JUN-2015  CSCHONG  1.2  SOS343199 (CS01)                          */
/************************************************************************/

CREATE PROC [dbo].[ispGenManifestSummarySerialReport] 
 ( @c_MbolKey  NVARCHAR(10) )
AS
BEGIN
  SET NOCOUNT ON

  DECLARE @c_DropID       NVARCHAR(18),
          @c_CartonGroup  NVARCHAR(10), 
          @n_FirstRec     int


  IF Object_id('tempdb..#ManifestSumm') IS NOT NULL 
      DROP TABLE #ManifestSumm

  SELECT ORDERS.StorerKey,   
   MBOL.MbolKey,   
   MBOLDETAIL.MbolLineNumber,
   MBOLDETAIL.OrderKey,  
   MBOLDETAIL.ExternOrderKey,  
   MBOLDETAIL.InvoiceNo,
   QtyCS = case when left(orders.storerkey,2)<>'c4' then MBOLDETAIL.TotalCartons else 0 end,
   QtyPL = case when left(orders.storerkey,2)<>'c4' then 0 else MBOLDETAIL.TotalCartons end,
   QtyDesp = SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty), 
   WgtDesp = SUM((ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.STDGROSSWGT),
   CubicDesp = SUM((ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.STDCUBE),
   MBOL.VoyageNumber,   
   MBOL.LoadingDate,   
   mbol.ADDDATE,
   MBOL.DepartureDate, 
   MBOLDETAIL.OrderDate,
   MBOLDETAIL.DeliveryDate,   
   ORDERS.Route,   
   ORDERS.Stop,   
   MBOL.CarrierKey,   
   CARRIER_NAME = STORER_B.Company,
   MBOL.Vessel,   
   MBOL.VESSELQUALIFIER,  
   MBOL.TransMethod,   
   MBOL.DRIVERName,   
   mbol.OriginCountry,
   MBOL.DestinationCountry,
   MBOL.ArrivalDate,
   mbol.BookingReference,
   mbol.OtherReference,
   mbol.PlaceOfdischargeQualifier,
   mbol.PlaceOfDischarge, 
   mbol.PlaceOfLoadingQualifier,
   mbol.PlaceOfLoading,
   mbol.PlaceOfdeliveryQualifier,
   mbol.PlaceOfdelivery,
   mbol.UserDefine01,
   mbol.UserDefine02,
   mbol.UserDefine03,
   Vessel_hd = case when mbol.VESSELQUALIFIER <> '' then (select left(Description, len(Description)) from codelkup (nolock) where LISTNAME = 'VESSELS' and Code = mbol.VESSELQUALIFIER) else '' end ,
   Type_hd = case when mbol.transmethod <> '' then (select left(Description, len(Description)) from codelkup (nolock) where LISTNAME = 'TRANSMETH' and Code = mbol.transmethod) else '' end ,
   Country_hd = case when mbol.OriginCountry <> '' then (select left(Description, len(Description)) from codelkup (nolock) where LISTNAME = 'ISOCOUNTRY' and Code = mbol.OriginCountry) else '' end ,
   Destination_hd = case when mbol.DestinationCountry <> '' then (select left(Description, len(Description)) from codelkup (nolock) where LISTNAME = 'ISOCOUNTRY' and Code = mbol.DestinationCountry) else '' end ,
   --(Wan01) - START
   Remarks = CASE WHEN SC.SVALUE = '1' AND ISNULL(RTRIM(CONVERT(NVARCHAR(120),CS.Notes1)), '') <> '' 
                  THEN CS.Notes1 ELSE substring(MBOL.Remarks,1 , 120) END,
   --(Wan01) - END
   STORER.Company,
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.Address4,
   STORER.PHONE1,
   STORER.fax1,
   STORER.Contact1,
   B_Company = STORER_B.Company,
   B_Address1 = STORER_B.Address1,
   B_Address2 = STORER_B.Address2,
   B_Address3 = STORER_B.Address3,
   B_Address4 = STORER_B.Address4,
   B_PHONE1   = STORER_B.PHONE1,
   B_FAX1     = STORER_B.fax1,
   B_Contact1 = STORER_B.Contact1,
   ORDERS.C_Company, 
   ORDERS_c_ADDRESS1 = ISNULL(ORDERS.c_ADDRESS1, ''),
   ORDERS_c_ADDRESS2 = ISNULL(ORDERS.c_ADDRESS2, ''),
   ORDERS_c_ADDRESS3 = ISNULL(ORDERS.c_ADDRESS3, ''),
   ORDERS_c_ADDRESS4 = ISNULL(ORDERS.c_ADDRESS4, ''), 
   PalletRow = 0,
   PalletID1  = SPACE(60),
   PalletID2  = SPACE(60),
   PalletID3  = SPACE(60)
   INTO #ManifestSumm
   FROM MBOL        WITH (NOLOCK)
   --(Wan01) - START
   JOIN MBOLDETAIL  WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey )
   JOIN ORDERS      WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey )
   JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
   JOIN STORER      WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey ) 
   JOIN SKU         WITH (NOLOCK) ON ( ORDERDETAIL.Storerkey = SKU.Storerkey) and
                                     ( ORDERDETAIL.SKU = SKU.SKU )
   LEFT OUTER JOIN STORER AS STORER_B WITH (NOLOCK) ON ( STORER_B.Storerkey = MBOL.Carrierkey )
   LEFT JOIN STORER AS CS    WITH (NOLOCK) ON ( ORDERS.Consigneekey = CS.Storerkey )
   LEFT JOIN STORERCONFIG SC WITH (NOLOCK) ON  (STORER.Storerkey = SC.Storerkey)
                                           AND (SC.Configkey= 'CONSIGNEEREMARK')
   --(Wan01) - END
   --(CS01) - Start
   LEFT JOIN CODELKUP CK (NOLOCK) ON (CK.Listname='REPORTCFG' 
                                  AND CK.long='r_dw_manifest_summary_serial' 
                                  AND CK.Storerkey = ORDERS.StorerKey 
                                  AND CK.Code='SHOWRPT'
                                  AND CK.short='Y')
   WHERE Mbol.mbolkey = @c_MBOLKEY 
   AND (1 = CASE  
       WHEN CK.short = 'Y' AND (mbol.status<'9') THEN '0'
       WHEN  CK.short = 'Y' AND  (mbol.status ='9') THEN '1'
     ELSE '1'
   END )
   --(CS01) - End
   GROUP BY ORDERS.StorerKey,   
   MBOL.MbolKey,   
   MBOLDETAIL.MbolLineNumber,
   MBOLDETAIL.OrderKey,  
   mbol.OriginCountry,
   MBOLDETAIL.ExternOrderKey,  
   MBOLDETAIL.InvoiceNo,
   MBOLDETAIL.TotalCartons,
   MBOL.VoyageNumber,   
   MBOL.LoadingDate,   
   mbol.ADDDATE,
   MBOL.DepartureDate, 
   MBOLDETAIL.OrderDate,
   MBOL.ArrivalDate,
   MBOLDETAIL.DeliveryDate,   
   ORDERS.Route,   
   ORDERS.Stop,   
   MBOL.CarrierKey,   
   STORER_B.Company,
   MBOL.Vessel,   
   MBOL.TransMethod,   
   MBOL.DRIVERName,   
   STORER.Company,
   mbol.BookingReference,
   mbol.OtherReference,
   mbol.PlaceOfdischargeQualifier,
   mbol.PlaceOfDischarge, 
   mbol.PlaceOfLoadingQualifier,
   mbol.PlaceOfLoading,
   mbol.PlaceOfdeliveryQualifier,
   mbol.PlaceOfdelivery,
   mbol.UserDefine01,
   mbol.UserDefine02,
   mbol.UserDefine03,
   --(Wan01) - START
   CASE WHEN SC.SVALUE = '1' AND ISNULL(RTRIM(CONVERT(NVARCHAR(120),CS.Notes1)), '') <> '' 
        THEN CS.Notes1 ELSE substring(MBOL.Remarks,1 , 120) END,
   --(Wan01) - END
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.Address4,
   STORER.PHONE1,
   STORER.fax1,   
   STORER.Contact1,
   STORER_B.Company,
   STORER_B.Address1,
   STORER_B.Address2,
   STORER_B.Address3,
   STORER_B.Address4,
   STORER_B.PHONE1,
   STORER_B.fax1, 
   STORER_B.Contact1,
   MBOL.VESSELQUALIFIER,  
   MBOL.DestinationCountry,
   ORDERS.C_Company, 
   ORDERS.c_ADDRESS1,  
   ORDERS.c_ADDRESS2,
   ORDERS.c_ADDRESS3,
   ORDERS.c_ADDRESS4

   DECLARE @n_PalletCnt   int,
           @c_PalletDesc  NVARCHAR(60), 
           @c_PalletDesc2 NVARCHAR(60), 
           @c_PalletDesc3 NVARCHAR(60), 
           @n_PalletRow   int 

   SET @n_PalletCnt = 1
   SET @n_FirstRec = 1 

   DECLARE Cur_PalletID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT PickDetail.DropID, PickDetail.CartonGroup 
   FROM MBOLDETAIL WITH (NOLOCK)  
   JOIN ORDERDETAIL WITH (NOLOCK)ON ( MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey ) 
   JOIN PICKDETAIL WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND
                                      ORDERDETAIL.OrderLineNumber = PickDetail.OrderLineNumber )
   WHERE MBOLDETAIL.MBOLKey = @c_MbolKey 
   AND   (PickDetail.DropID <> '' AND PickDetail.DropID IS NOT NULL)
   ORDER BY PickDetail.DropID 

   OPEN Cur_PalletID 

   FETCH NEXT FROM Cur_PalletID INTO @c_DropID, @c_CartonGroup
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_FirstRec = 1
      BEGIN
         SET @c_PalletDesc = 'Pallet#'
         SET @n_FirstRec = 0 
         SET @n_PalletRow = 1
         SET @n_PalletCnt = 5

--         INSERT INTO #ManifestSumm (StorerKey,MbolKey,MbolLineNumber,OrderKey,ExternOrderKey,
--            InvoiceNo, QtyCS,QtyPL, QtyDesp, WgtDesp,CubicDesp,VoyageNumber,LoadingDate,
--            ADDDATE,   DepartureDate, OrderDate, DeliveryDate,Route,Stop,CarrierKey,CARRIER_NAME,
--            Vessel,VESSELQUALIFIER,TransMethod,DRIVERName,OriginCountry,DestinationCountry,ArrivalDate,
--            BookingReference,OtherReference,PlaceOfdischargeQualifier,PlaceOfDischarge,
--            PlaceOfLoadingQualifier,PlaceOfLoading,PlaceOfdeliveryQualifier,PlaceOfdelivery,
--            UserDefine01,UserDefine02,UserDefine03,Vessel_hd,Type_hd,Country_hd,Destination_hd,Remarks,
--            Company,Address1,Address2,Address3,Address4,PHONE1,fax1,Contact1,B_Company,B_Address1,
--            B_Address2,B_Address3,B_Address4,B_PHONE1,B_FAX1,B_Contact1,C_Company,ORDERS_c_ADDRESS1,
--            ORDERS_c_ADDRESS2,ORDERS_c_ADDRESS3,ORDERS_c_ADDRESS4,PalletRow,PalletID1, PalletID2, PalletID3)
--         VALUES ('',@c_MbolKey,'99999','','','', 0,0, 0, 0,0,'','19000101','19000101', 
--                 '19000101', '19000101', '19000101','','','','','','','','','','','',
--                 '','','','','','','','','','','','','','','','','','','','','','','',
--                 '','','','','','','','','','','','','','',1,'Pallet#', '', '')
      END

      IF @n_PalletCnt <= 12  
      BEGIN
         IF @n_PalletCnt = 0 
            SET @c_PalletDesc = @c_DropID + 
                               CASE WHEN @c_CartonGroup = 'M' Then '*' ELSE '' END
         ELSE 
         BEGIN
            IF @n_PalletCnt between 1 AND 4 
               SET @c_PalletDesc = LTRIM(RTRIM( @c_PalletDesc )) + 
                                     CASE WHEN LEN(@c_PalletDesc) > 0 Then '    ' ELSE '' END +
                                     @c_DropID + 
                                     CASE WHEN @c_CartonGroup = 'M' Then '*   ' ELSE '' END
            ELSE IF @n_PalletCnt between 5 AND 8 
               SET @c_PalletDesc2 = LTRIM(RTRIM( @c_PalletDesc2 )) + 
                                     CASE WHEN LEN(@c_PalletDesc2) > 0 Then '    ' ELSE '' END +
                                     @c_DropID + 
                                     CASE WHEN @c_CartonGroup = 'M' Then '*  ' ELSE '' END
            ELSE IF @n_PalletCnt between 9 AND 12 
               SET @c_PalletDesc3 = LTRIM(RTRIM( @c_PalletDesc3 )) + 
                                     CASE WHEN LEN(@c_PalletDesc3) > 0 Then '    ' ELSE '' END +
                                     @c_DropID + 
                                     CASE WHEN @c_CartonGroup = 'M' Then '*   ' ELSE '' END
         END

         SET @n_PalletCnt = @n_PalletCnt + 1
      END 
      ELSE
      BEGIN
         SET @n_PalletRow = @n_PalletRow + 1

         SET ROWCOUNT 1

         INSERT INTO #ManifestSumm (StorerKey,MbolKey,MbolLineNumber,OrderKey,ExternOrderKey,
            InvoiceNo, QtyCS,QtyPL, QtyDesp, WgtDesp,CubicDesp,VoyageNumber,LoadingDate,
            ADDDATE,   DepartureDate, OrderDate, DeliveryDate,Route,Stop,CarrierKey,CARRIER_NAME,
            Vessel,VESSELQUALIFIER,TransMethod,DRIVERName,OriginCountry,DestinationCountry,ArrivalDate,
            BookingReference,OtherReference,PlaceOfdischargeQualifier,PlaceOfDischarge,
            PlaceOfLoadingQualifier,PlaceOfLoading,PlaceOfdeliveryQualifier,PlaceOfdelivery,
            UserDefine01,UserDefine02,UserDefine03,Vessel_hd,Type_hd,Country_hd,Destination_hd,Remarks,
            Company,Address1,Address2,Address3,Address4,PHONE1,fax1,Contact1,B_Company,B_Address1,
            B_Address2,B_Address3,B_Address4,B_PHONE1,B_FAX1,B_Contact1,C_Company,ORDERS_c_ADDRESS1,
            ORDERS_c_ADDRESS2,ORDERS_c_ADDRESS3,ORDERS_c_ADDRESS4,PalletRow,PalletID1, PalletID2, PalletID3)
         SELECT StorerKey,MbolKey,'99999',OrderKey,ExternOrderKey,
            InvoiceNo, 0,0, 0, 0,0,VoyageNumber,LoadingDate,
            ADDDATE,   DepartureDate, OrderDate, DeliveryDate,Route,Stop,CarrierKey,CARRIER_NAME,
            Vessel,VESSELQUALIFIER,TransMethod,DRIVERName,OriginCountry,DestinationCountry,ArrivalDate,
            BookingReference,OtherReference,PlaceOfdischargeQualifier,PlaceOfDischarge,
            PlaceOfLoadingQualifier,PlaceOfLoading,PlaceOfdeliveryQualifier,PlaceOfdelivery,
            UserDefine01,UserDefine02,UserDefine03,Vessel_hd,Type_hd,Country_hd,Destination_hd,Remarks,
            Company,Address1,Address2,Address3,Address4,PHONE1,fax1,Contact1,B_Company,B_Address1,
            B_Address2,B_Address3,B_Address4,B_PHONE1,B_FAX1,B_Contact1,'','',
            '','','',@n_PalletRow,@c_PalletDesc, @c_PalletDesc2, @c_PalletDesc3
         FROM #ManifestSumm 
         ORDER BY OrderKey DESC 

         SET ROWCOUNT 0 
--         VALUES ('',@c_MbolKey,'99999','','','', 0,0, 0, 0,0,'','19000101','19000101', 
--                 '19000101', '19000101', '19000101','','','','','','','','','','','',
--                 '','','','','','','','','','','','','','','','','','','','','','','',
--                 '','','','','','','','','','','','','','',@n_PalletRow,@c_PalletDesc, @c_PalletDesc2, @c_PalletDesc3)


         SET @c_PalletDesc = @c_DropID + 
                               CASE WHEN @c_CartonGroup = 'M' Then '*' ELSE '' END
         SET @c_PalletDesc2 = ''
         SET @c_PalletDesc3 = ''
         SET @n_PalletCnt = 2
      END 
      
         

      FETCH NEXT FROM Cur_PalletID INTO @c_DropID, @c_CartonGroup
   END
   CLOSE Cur_PalletID
   DEALLOCATE Cur_PalletID

   IF LEN(@c_PalletDesc) > 0 OR LEN(@c_PalletDesc2) > 0 OR LEN(@c_PalletDesc3) > 0
   BEGIN         
      SET @n_PalletRow = @n_PalletRow + 1

      SET ROWCOUNT 1

      INSERT INTO #ManifestSumm (StorerKey,MbolKey,MbolLineNumber,OrderKey,ExternOrderKey,
      InvoiceNo, QtyCS,QtyPL, QtyDesp, WgtDesp,CubicDesp,VoyageNumber,LoadingDate,
      ADDDATE,   DepartureDate, OrderDate, DeliveryDate,Route,Stop,CarrierKey,CARRIER_NAME,
      Vessel,VESSELQUALIFIER,TransMethod,DRIVERName,OriginCountry,DestinationCountry,ArrivalDate,
      BookingReference,OtherReference,PlaceOfdischargeQualifier,PlaceOfDischarge,
      PlaceOfLoadingQualifier,PlaceOfLoading,PlaceOfdeliveryQualifier,PlaceOfdelivery,
      UserDefine01,UserDefine02,UserDefine03,Vessel_hd,Type_hd,Country_hd,Destination_hd,Remarks,
      Company,Address1,Address2,Address3,Address4,PHONE1,fax1,Contact1,B_Company,B_Address1,
      B_Address2,B_Address3,B_Address4,B_PHONE1,B_FAX1,B_Contact1,C_Company,ORDERS_c_ADDRESS1,
      ORDERS_c_ADDRESS2,ORDERS_c_ADDRESS3,ORDERS_c_ADDRESS4,PalletRow,PalletID1, PalletID2, PalletID3)
      SELECT StorerKey,MbolKey,'99999',OrderKey,ExternOrderKey,
         InvoiceNo, 0,0, 0, 0,0,VoyageNumber,LoadingDate,
         ADDDATE,   DepartureDate, OrderDate, DeliveryDate,Route,Stop,CarrierKey,CARRIER_NAME,
         Vessel,VESSELQUALIFIER,TransMethod,DRIVERName,OriginCountry,DestinationCountry,ArrivalDate,
         BookingReference,OtherReference,PlaceOfdischargeQualifier,PlaceOfDischarge,
         PlaceOfLoadingQualifier,PlaceOfLoading,PlaceOfdeliveryQualifier,PlaceOfdelivery,
         UserDefine01,UserDefine02,UserDefine03,Vessel_hd,Type_hd,Country_hd,Destination_hd,Remarks,
         Company,Address1,Address2,Address3,Address4,PHONE1,fax1,Contact1,B_Company,B_Address1,
         B_Address2,B_Address3,B_Address4,B_PHONE1,B_FAX1,B_Contact1,'','',
         '','','',@n_PalletRow,LTRIM(@c_PalletDesc), LTRIM(@c_PalletDesc2), LTRIM(@c_PalletDesc3)
      FROM #ManifestSumm 
      ORDER BY OrderKey DESC 

      SET ROWCOUNT 0
--      VALUES ('',@c_MbolKey,'99999','','','', 0,0, 0, 0,0,'','19000101','19000101', 
--           '19000101', '19000101', '19000101','','','','','','','','','','','',
--           '','','','','','','','','','','','','','','','','','','','','','','',
--           '','','','','','','','','','','','','','',@n_PalletRow,LTRIM(@c_PalletDesc), LTRIM(@c_PalletDesc2), LTRIM(@c_PalletDesc3))
   END 

   SELECT * FROM #ManifestSumm -- where PalletRow > 0
   ORDER BY MBOLKey, MBOLLineNumber, PalletRow

END -- End Procedure 

GO