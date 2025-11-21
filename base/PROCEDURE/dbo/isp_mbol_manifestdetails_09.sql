SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store Procedure: isp_Mbol_Manifestdetails_09                               */
/* Creation Date: 22-AUG-2022                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose: WMS-20252 -  [CN] Columbia_POD_ChangeRequest                      */
/*                                                                            */
/*                                                                            */
/* Called By:  r_dw_manifest_detail_09.srd                                    */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/* 22-AUG-2022  CHONGCS   1.0   Devops Scripts Combine                        */
/******************************************************************************/

CREATE PROC [dbo].[isp_Mbol_Manifestdetails_09]
       (@c_Mbolkey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @c_getmbolkey       NVARCHAR(10)
         ,@c_consigneekey     NVARCHAR(45)
         ,@c_short            NVARCHAR(10)
         ,@c_Preshort         NVARCHAR(10)
         ,@c_delimiter        NVARCHAR(1)
         ,@c_getnotes         NVARCHAR(50)




    SELECT MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,   
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,   
         RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')' AS state_city,  
         ORDERS.C_Zip,
         QTY =  SUM(ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),
         STORER.company,

         FACILITY.Userdefine11 AS Address1,     
         FACILITY.Userdefine12 AS Address2,
         FACILITY.Userdefine13 AS Address3, 
         FACILITY.Userdefine14 AS Address4,
         FACILITY.Userdefine06 AS CONtact1,
         FACILITY.Userdefine07 AS PhONe1,
         CONVERT(NVARCHAR(4000),STORER.Notes2) as Notes, 
         MD.TotalCartons,  
         Item_Type = Left(LTRIM(ORDERDETAIL.SKU), 1),
         CodeLKUP.Short,
         ProdUnit = ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
         N'LFL运输' as Carrier_Company,
         Right(RTrim(CL2.Short),3) as Principle,
         CASE MBOL.TransMethod WHEN 'R' THEN '0' WHEN 'A' THEN '0' WHEN 'E' THEN '0' ELSE '1' END as TransMethod_0,
         CASE MBOL.TransMethod WHEN 'R' THEN '1' ELSE '0' END as TransMethod_1,
         CASE MBOL.TransMethod WHEN 'A' THEN '1' ELSE '0' END as TransMethod_2,
         CASE MBOL.TransMethod WHEN 'E' THEN '1' ELSE '0' END as TransMethod_3,
         CONVERT(VARCHAR(8),MBOL.EditDate, 112) AS editdate,
         CONVERT(VARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL3.SHORT,0)), MBOL.EditDate), 112) as arrivaldate,
         CONVERT(NVARCHAR(4000),MBOL.Remarks) as Remarks,
         FACILITY.Userdefine15 AS CompanyName,
         ISNULL(CL4.Short,'') AS CL4Short,
         ISNULL(CL5.short,'N') AS ShowField,
      ORDERS.Externorderkey,  
      --CASE WHEN ISNULL(CL6.short,'') <> '' THEN ISNULL(CL6.long,'') ELSE ISNULL(ORDERS.Notes,'') END AS OHNotes,   
      CASE WHEN ISNULL(ORDERS.Consigneekey,'') LIKE 'RCN%' THEN N'零售' + SPACE(2) + ISNULL(ORDERS.Notes,'')  ELSE N'批发' + SPACE(2) + ISNULL(ORDERS.Notes,'') END AS OHNotes,   
      ORDERS.Orderkey   
   FROM ORDERDETAIL WITH (NOLOCK)   
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )
     JOIN MBOLDETAIL MD (NOLOCK) ON MD.Orderkey = ORDERS.Orderkey    
   JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )   
   JOIN MBOL WITH (NOLOCK)   ON ( ORDERDETAIL.Mbolkey = MBOL.Mbolkey )
   JOIN SKU WITH (NOLOCK)    ON ( SKU.SKU = ORDERDETAIL.SKU AND SKU.Storerkey = ORDERDETAIL.Storerkey )
   JOIN FACILITY WITH (NOLOCK) ON ( FACILITY.Facility = ORDERS.Facility)   
   LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) 
               ON ( CARRIER.Storerkey = CASE ISNULL(MBOL.Carrierkey,'') WHEN '' THEN STORER.SUSR1 ELSE MBOL.Carrierkey END)
   LEFT OUTER JOIN CodeLKUP WITH (NOLOCK) ON ( CodeLKUP.ListName = 'SKUFLAG' AND CodeLKUP.Code = SKU.SkuGroup  ) 
   LEFT OUTER JOIN Codelkup CL2 WITH (NOLOCK) ON (CL2.Listname = 'strdomain' AND CL2.Code = ORDERS.Storerkey)
   LEFT OUTER JOIN CODELKUP CL3 WITH (NOLOCK)
               ON (CL3.Listname = 'CityLdTime' AND CONVERT(VARCHAR,CL3.Notes) = ORDERS.Storerkey
               AND ISNULL(RTRIM(CL3.Description),'') = ISNULL(RTRIM(ORDERS.C_City),'')
               AND ISNULL(RTRIM(CL3.Long),'') = ISNULL(RTRIM(FACILITY.UserDefine03),''))
   LEFT OUTER JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.listname = 'CMBSKUCODE' and CL4.code = sku.BUSR2 and CL4.storerkey=ORDERS.Storerkey 
   LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON CL5.LISTNAME='REPORTCFG' AND CL5.Storerkey = ORDERS.StorerKey 
                          AND CL5.Long='r_dw_manifest_detail_09' AND CL5.code='SHOWFIELD' 
   LEFT OUTER JOIN CODELKUP CL6 WITH (NOLOCK) ON CL6.listname = 'CSGNOTE' and CL6.short = ORDERS.consigneekey and CL6.storerkey=ORDERS.Storerkey 
   WHERE ( MBOL.Mbolkey = @c_Mbolkey ) 
   GROUP BY  MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,   
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,  
         RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')',
         ORDERS.C_Zip,
         STORER.company,
         FACILITY.Userdefine11,     
         FACILITY.Userdefine12,
         FACILITY.Userdefine13,
         FACILITY.Userdefine14,
         FACILITY.Userdefine06,
         FACILITY.Userdefine07,
         CONVERT(NVARCHAR(4000),STORER.Notes2), 
         Left(LTRIM(ORDERDETAIL.SKU), 1),
         CodeLKUP.Short,
         ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
         --ISNULL(CARRIER.Company, ''),
         Right(RTrim(CL2.Short),3),
         CASE MBOL.TransMethod WHEN 'R' THEN '0' WHEN 'A' THEN '0' WHEN 'E' THEN '0' ELSE '1' END,
         CASE MBOL.TransMethod WHEN 'R' THEN '1' ELSE '0' END,
         CASE MBOL.TransMethod WHEN 'A' THEN '1' ELSE '0' END,
         CASE MBOL.TransMethod WHEN 'E' THEN '1' ELSE '0' END,
         CONVERT(VARCHAR(8),MBOL.EditDate, 112), 
         CONVERT(VARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL3.SHORT,0)), MBOL.EditDate), 112),
         CONVERT(NVARCHAR(4000),MBOL.Remarks),
         FACILITY.Userdefine15 ,ISNULL(CL4.Short,''),ISNULL(CL5.short,'N'),
      ORDERS.Externorderkey,  
      CASE WHEN ISNULL(ORDERS.Consigneekey,'') LIKE 'RCN%' THEN N'零售' + SPACE(2) + ISNULL(ORDERS.Notes,'')  ELSE N'批发' + SPACE(2) + ISNULL(ORDERS.Notes,'') END,  
      ORDERS.Orderkey,  
      MD.TotalCartons   

END



GO