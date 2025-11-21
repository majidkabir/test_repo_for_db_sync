SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_CartonManifestLabel40                          */
/* Creation Date: 24 FEB 2023                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21689 -MYSûJDSPORTSMYûNew Packing Label for SF Express  */
/*                                                                      */
/* Called By: r_dw_carton_manifest_Label_40                             */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 08-FEB-2023  CSCHONG 1.0   Devops Scripts Combine                    */
/* 29-MAR-2023  CSCHONG 1.1   WMS-22160 revised field logic (CS01)      */
/************************************************************************/

CREATE   PROC [dbo].[isp_CartonManifestLabel40] (
      @c_Pickslipno     NVARCHAR(10))
   --,  @c_StartcartonNo  NVARCHAR(5) = ''
   --,  @c_EndcartonNo    NVARCHAR(5) = '')
 AS
 BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


CREATE TABLE #TMPCTNMNF40  (
            Orderkey        NVARCHAR(20)
         ,  PickSlipNo      NVARCHAR(10)  NULL
         ,  ExternOrdkey    NVARCHAR(50)  NULL
         ,  trackingno      NVARCHAR(20)  NULL
         ,  OrdDate         NVARCHAR(10)  NULL
         ,  DELDate         NVARCHAR(10)  NULL
         ,  C_Company       NVARCHAR(45)  NULL
         ,  C_address1      NVARCHAR(45)  NULL
         ,  C_address2      NVARCHAR(45)  NULL
         ,  C_address3      NVARCHAR(45)  NULL
         ,  C_address4      NVARCHAR(45)  NULL
         ,  C_City          NVARCHAR(45)  NULL
         ,  C_state         NVARCHAR(45)  NULL
         ,  C_Country       NVARCHAR(45)  NULL
         ,  C_Zip           NVARCHAR(45)  NULL
         ,  C_phone1        NVARCHAR(45)  NULL
         ,  ShipperName     NVARCHAR(150)  NULL
         ,  ShipperPhone    NVARCHAR(150)  NULL
         ,  ShipperEmail    NVARCHAR(150)  NULL
         ,  ShipperAdd1     NVARCHAR(150)  NULL
         ,  ShipperAdd2     NVARCHAR(150)  NULL
         ,  ShipperAdd3     NVARCHAR(150)  NULL
         ,  ShipperCity     NVARCHAR(150)  NULL
         ,  ShipperState    NVARCHAR(150)  NULL
         ,  ShipperPost     NVARCHAR(150)  NULL
         ,  CompanyName     NVARCHAR(45)  NULL
         ,  Companyadd1     NVARCHAR(45)  NULL
         ,  Companyadd2     NVARCHAR(45)  NULL
         ,  Companyadd3     NVARCHAR(45)  NULL
         ,  Companyadd4     NVARCHAR(45)  NULL
         ,  CompanyCity     NVARCHAR(45)  NULL
         ,  Companystate    NVARCHAR(45)  NULL
         ,  CompanyZip      NVARCHAR(45)  NULL
         ,  CompanyCountry  NVARCHAR(45)  NULL
         ,  CompanyContact  NVARCHAR(45)  NULL
         ,  Companyphone    NVARCHAR(45)  NULL
         ,  CompanyEmail    NVARCHAR(45)  NULL
         ,  skugrp          NVARCHAR(10)  NULL
         ,  itemtype        NVARCHAR(10)  NULL
         ,  sku             NVARCHAR(20)  NULL
         ,  Unitprice       FLOAT         NULL
         ,  QtyPicked       INT           NULL
         ,  shipqty         INT           NULL
         ,  currency        NVARCHAR(30)  NULL
         ,  itemvalue       FLOAT         NULL
         ,  itemwgt         FLOAT         NULL
         ,  content         NVARCHAR(150)  NULL

)
 INSERT INTO #TMPCTNMNF40
 (
     Orderkey,
     PickSlipNo,
     ExternOrdkey,
     trackingno,
     OrdDate,
     DELDate,
     C_Company,
     C_address1,
     C_address2,
     C_address3,
     C_address4,
     C_City,
     C_state,
     C_Country,
     C_Zip,
     C_phone1,
     ShipperName,
     ShipperPhone,
     ShipperEmail,
     ShipperAdd1,
     ShipperAdd2,
     ShipperAdd3,
     ShipperCity,
     ShipperState,
     ShipperPost,
     CompanyName,
     Companyadd1,
     Companyadd2,
     Companyadd3,
     Companyadd4,
     CompanyCity,
     Companystate,
     CompanyZip,
     CompanyCountry,
     CompanyContact,
     Companyphone,
     CompanyEmail,
     skugrp,
     itemtype,
     sku,
     Unitprice,
     QtyPicked,
     shipqty,
     currency,
     itemvalue,
     itemwgt,
     content
 )
 select
      o.orderkey,
      ph.pickslipno,
      o.ExternOrderKey,
      o.TrackingNo,
      CONVERT(NVARCHAR(10),o.OrderDate,105),
      CONVERT(NVARCHAR(10),o.DeliveryDate,105),
      o.C_Company, 
      o.C_Address1, 
      o.C_Address2, 
      o.C_Address3, 
      o.C_Address4, 
      o.C_City, 
      o.C_State, 
      o.C_Country,
      o.C_Zip, 
      o.c_phone1,
      ShipperName = isnull(clk1.long,''),
      ShipperPhone = isnull(clk1.Notes,''),
      ShipperEmail = isnull(clk1.Notes2,''),
      ShipperAdd1 = isnull(clk1.UDF01,''),
      ShipperAdd2 = isnull(clk1.UDF02,''),
      ShipperAdd3 = isnull(clk1.UDF03,''),
      ShipperCity = isnull(clk1.UDF04,''),
      ShipperState = isnull(clk1.UDF05,''),
      ShipperPost = isnull(clk1.code2,''),
      CompanyName = isnull(s.Company,''),
      CompanyAdd1 = isnull(s.Address1,''),
      CompanyAdd2 = isnull(s.Address2,''),
      CompanyAdd3 = isnull(s.Address3,''),
      CompanyAdd4 = isnull(s.Address4,''),
      CompanyCity = isnull(s.city,''),
      CompanyState = isnull(s.state,''),
      CompanyZip = isnull(s.zip,''),
      CompanyCntry = isnull(s.country,''),
      Companycontact = isnull(s.contact1,''),
      CompanyPhone = isnull(s.phone1,''),
      CompanyEmail = isnull(s.Email1,''),
      skugroup = isnull(sku.skugroup,''),
      type = isnull(clk2.short,''),
      od.sku,
      od.UnitPrice,
      od.QtyPicked,
      od.ShippedQty,
      Currency = isnull(clk2.code2,''),
      ItemValue = 0.00, --convert(numeric(10,2),IsNull(od.UnitPrice,0.00) * (od.QtyPicked + od.ShippedQty)),    --CS01
      ItemWeight = Case when sku.stdgrosswgt <> 0 
                  then convert(numeric(10,2), sku.stdgrosswgt * (od.QtyPicked + od.ShippedQty))
                  else convert(numeric(10,2), sku.grosswgt * (od.QtyPicked + od.ShippedQty)) end,
                  

      content = LTRIM(STUFF((SELECT DISTINCT '; ' + TRIM(abc.skugroup) + ':' + convert(varchar(8),abc.qty) + uom 
               FROM (select b.skugroup, qty = sum(pd.qty), uom = max(pack.PackUOM3)
                     from packdetail pd with (nolock)
                        inner join sku b with (nolock)
                        on pd.storerkey = b.storerkey
                        and pd.sku = b.sku
                        inner join pack with (nolock)
                        on b.packkey = pack.packkey
                     where pd.pickslipno = ph.pickslipno
                     group by b.skugroup) abc 
               FOR XML PATH('')),1,1,'' ))

   from orders o with (nolock)
         inner join orderdetail od with (nolock)
         on o.orderkey = od.orderkey
         and od.QtyPicked + od.ShippedQty > 0

         inner join packheader ph with (nolock)
         on o.orderkey = ph.orderkey
         and ph.status = '9'

         left outer join codelkup clk1 with (nolock)
         on clk1.listname = 'SFESHPLBL'
         and clk1.code = 'SHIPPERLOC'

         left outer join codelkup clk2 with (nolock)
         on clk2.listname = 'SFESHPLBL'
         and clk2.code = 'SFEAPISHPINFO'

         inner join storer s with (nolock)
         on o.storerkey = s.storerkey

         inner join sku with (nolock)
         on od.StorerKey = sku.StorerKey
         and od.sku = sku.sku
   where o.shipperkey = 'SFE' 
   and o.storerkey = 'JDSPORTSMY'
   AND o.DocType='E'
   and ph.pickslipno = @c_pickslipno
    

  Select
            orderkey,
            TrackingNo,
            C_Company,
            C_Country,
            C_Address1,
            C_Address2,
            C_Address3,
            C_Address4,
            C_City,
            C_Zip,
            C_State,
            OrdDate,
            ExternOrdkey,
            c_phone1,
            ShipperName,
            DELDate,
            ShipperPhone,
            pickslipno,
            ShipperEmail,
            ShipperAdd1,
            ShipperAdd2,
            ShipperAdd3 = ShipperAdd3 ,
            TotalQty = sum(QtyPicked) + sum(shipqty),
            ShipperCity =  ShipperCity ,
            ShipperState = ShipperState ,
            ShipperPost = ShipperPost  ,
            CompanyName,
            CompanyAdd1,
            CompanyAdd2,
            CompanyAdd3,
            CompanyAdd4,
            CompanyCity,
            CompanyState,
            CompanyZip,
            CompanyCountry,
            Companycontact,
            CompanyPhone,
            CompanyEmail,
            content = max(content),
            itemtype,
            TotalSku = count(distinct sku),
            Currency = Max(Currency),
            TotalItemValue = sum(ItemValue),
            TotalItemWeight = sum(itemwgt),
            RecAddLine3 = CASE WHEN C_address3<>'' AND C_address4 <> '' THEN C_address3 + ' ' + C_address4 
                          ELSE c_zip + ' ' + C_City + ' ' + C_state + ' ' + C_Country END,  
            RecAddLine4 =  CASE WHEN C_address3<>'' AND C_address4 <> '' THEN c_zip + ' ' + C_City + ' ' + C_state + ' ' + C_Country
                            ELSE '' END,
            SenderAddLine3 = CASE WHEN ISNULL(ShipperAdd3,'') = '' THEN  shipperpost + space(1) +  shippercity + space(1) +  shipperstate  ELSE ShipperAdd3 END,
                          --ELSE c_zip + ' ' + C_City + ' ' + C_state + ' ' + C_Country END,  
            SenderAddLine4 =  CASE WHEN ISNULL(ShipperAdd3,'') <> '' THEN shipperpost + space(1) +  shippercity + space(1) +  shipperstate
                            ELSE '' END
   FROM #TMPCTNMNF40
   GROUP BY 
   orderkey,
   pickslipno,
   ExternOrdkey,
   TrackingNo,
   OrdDate,
   DELDate,
   C_Company,
   C_Address1,
   C_Address2,
   C_Address3,
   C_Address4,
   C_City,
   C_State,
   C_Country,
   C_Zip,
   c_phone1,
   ShipperName,
   ShipperPhone,
   ShipperEmail,
   ShipperAdd1,
   ShipperAdd2,
   ShipperAdd3 ,
   ShipperCity ,
   ShipperState ,
   ShipperPost ,
   CompanyName,
   CompanyAdd1,
   CompanyAdd2,
   CompanyAdd3,
   CompanyAdd4,
   CompanyCity,
   CompanyState,
   CompanyZip,
   CompanyCountry,
   Companycontact,
   CompanyPhone,
   CompanyEmail,
   itemtype

  QUIT_SP:


   IF OBJECT_ID('tempdb..#TMPCTNMNF40') IS NOT NULL
      DROP TABLE #TMPCTNMNF40

END

GO