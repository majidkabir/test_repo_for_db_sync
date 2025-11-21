SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_delivery_note13                                     */
/* Creation Date: 11-NOV-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11092 - IDSMED Delivery Note (Convert to calling SP)    */
/*        :                                                             */
/* Called By: r_dw_delivery_note13                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 12/11/2019  mingle01 1.0   use case when to select orders.incoterm   */
/*                            else orders.storerkey and add codelkup    */
/* 3/12/2019   mingle01 1.1   continue to use case when to select       */
/*                            orders.incoterm else orders.storerkey     */
/* 08/05/2020  WLChooi  1.2   WMS-13267 - Add ReportCFG to remove logo  */
/*                            (WL01)                                    */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note13]
         @c_Mbolkey     NVARCHAR(10) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT

   SET @n_continue = 1

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT --ORDERS.Storerkey,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN B.Storerkey ELSE A.Storerkey END ELSE ORDERS.STORERKEY END,       --mingle01
             SUBSTRING(ORDERS.ExternOrderKey,5,26) AS ExternOrderkey,
             ORDERS.Route,
             ORDERS.Facility, 
             ORDERS.ConsigneeKey,   
             ORDERS.C_Company,   
             ORDERS.C_Address1,   
             ORDERS.C_Address2, 
             ORDERS.C_Address3,
             ORDERS.C_Address4,   
             ORDERS.C_City,
             ORDERS.C_Zip,
             ORDERS.C_Contact1,
             ORDERS.C_Contact2,
             ORDERS.C_Phone1,
             ORDERS.C_Phone2,
             --start --mingle01
             --ORDERS.BillToKey,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.BillToKey ELSE ORDERS.ConsigneeKey END 
                  ELSE ORDERS.BillToKey END AS billtokey,
             --ORDERS.B_Company,   
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Company ELSE B.Company END 
                  ELSE ORDERS.B_Company END AS b_company,
             --ORDERS.B_Address1,  
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address1 ELSE B.Address1 END 
                  ELSE ORDERS.B_Address1 END AS b_address1, 
             --ORDERS.B_Address2, 
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address2 ELSE B.Address2 END 
                  ELSE ORDERS.B_Address2 END AS b_address2,
             --ORDERS.B_Address3,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address3 ELSE B.Address3 END 
                  ELSE ORDERS.B_Address3 END AS b_address3,
             --ORDERS.B_Address4,  
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address4 ELSE B.Address4 END 
                  ELSE ORDERS.B_Address4 END AS b_address4,
             --ORDERS.B_City,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_City ELSE B.City END 
                  ELSE ORDERS.B_City END AS b_city,
             --ORDERS.B_Zip,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Zip ELSE B.Zip END 
                  ELSE ORDERS.B_Zip END AS b_zip,
             --ORDERS.B_Contact1,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Contact1 ELSE B.Contact1 END 
                  ELSE ORDERS.B_Contact1 END AS b_contact1,
             --ORDERS.B_Contact2,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Contact2 ELSE B.Contact2 END 
                  ELSE ORDERS.B_Contact2 END AS b_contact2,
             --ORDERS.B_Phone1,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Phone1 ELSE B.Phone1 END 
                  ELSE ORDERS.B_Phone1 END AS b_phone1,
             --ORDERS.B_Phone2,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Phone2 ELSE B.Phone2 END 
                  ELSE ORDERS.B_Phone2 END AS b_phone2,
             --end --mingle01
             ORDERS.OrderKey,
             ORDERS.Adddate,
             ORDERS.DeliveryDate,
             ORDERS.Salesman,
             ORDERS.BuyerPO,  
             ORDERDETAIL.SKU,
             SKU.DESCR,
             ORDERDETAIL.UOM,  
             LOTATTRIBUTE.Lottable02,
             LOTATTRIBUTE.Lottable04,
             C.Notes1,
             C.Notes2,
             SUM(PICKDETAIL.Qty) AS Qty, 
             SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),1,87) AS NOTES1_1,  
             SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),88,87) AS NOTES1_2,  
             SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),175,76) AS NOTES1_3,
             ISNULL(CODELKUP.Description,'') AS CopyDesc,
             /* CASE WHEN ISNULL(CODELKUP.Notes,'') = '' THEN 'DELIVERY NOTE' ELSE CODELKUP.Notes END AS ReportTitle, SOS320977*/
             CASE WHEN ISNULL(CODELKUP.Notes,'') = '' AND ORDERS.Type <> 'AXTO'  THEN 'DELIVERY NOTE' 
                  WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey <> '61280' THEN 'DELIVERY NOTE' 
                  WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey = '61280' THEN 'WAREHOUSE STOCK TRANSFER' 
                  ELSE CODELKUP.Notes END AS ReportTitle,
             ISNULL(CODELKUP.Code,'') AS Copy,
             --start --mingle01
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Company ELSE A.Company END 
                  ELSE 'PT. IDS MEDICAL SYSTEMS INDONESIA' END,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address1 ELSE A.Address1 END 
                  ELSE 'WISMA 76 17TH FLOOR' END,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address2 ELSE A.Address2 END 
                  ELSE 'JL. LETJEND. S. PARMAN KAV. 76' END,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN (LTRIM(RTRIM(ISNULL(C.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(C.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(C.Country,''))))  
                                                   ELSE (LTRIM(RTRIM(ISNULL(A.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(A.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(A.Country,'')))) END 
                  ELSE 'SLIPI - JAKARTA 11410, INDONESIA' END AS Address3,
             CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN ('Tel: ' + (LTRIM(RTRIM(ISNULL(C.Phone1,'')))) + ', ' + 'Fax: ' + TRIM(RTRIM(ISNULL(C.Fax1,'')))) 
                                                   ELSE ('Tel: ' + (LTRIM(RTRIM(ISNULL(A.Phone1,'')))) + ', ' + 'Fax: ' + LTRIM(RTRIM(ISNULL(A.Fax1,''))))  END 
                  ELSE 'TEL: +62 21 2567 8989, FAX: +62 21 5366 1038' END as Fax,
             --end --mingle01
             ISNULL(CL2.Short,'N') AS RemoveLogo
      FROM ORDERS (NOLOCK)     
      JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey ) 
      JOIN PICKDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND    
                                  ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )  
      JOIN SKU (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) AND    
                            (SKU.Sku = ORDERDETAIL.Sku )     
      JOIN LOTATTRIBUTE (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot)     
      JOIN MBOL (NOLOCK) ON ( ORDERS.Mbolkey = MBOL.Mbolkey )    
      LEFT JOIN CODELKUP (NOLOCK) ON (ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname='REPORTCOPY' 
                                  AND CODELKUP.Long = 'r_dw_delivery_note13')  
      --start --mingle01
      LEFT JOIN STORER A (NOLOCK) ON A.StorerKey = ORDERS.IncoTerm                       
      JOIN STORER B (NOLOCK) ON B.Storerkey = CASE WHEN ISNULL(A.StorerKey,'') = '' THEN  ORDERS.Storerkey ELSE ORDERS.Consigneekey END --mingle01           
      JOIN STORER C (NOLOCK) ON C.Storerkey = ORDERS.Storerkey--mingle01      
      LEFT JOIN CODELKUP AS CL1 (NOLOCK) ON (ORDERS.Storerkey = CL1.Storerkey AND CL1.Listname='REPORTCFG' 
                                  AND CL1.Long = 'r_dw_delivery_note13') AND CL1.CODE = 'ShowIncoTermInfo'
      --end --mingle01
      --WL01 START
      LEFT JOIN CODELKUP AS CL2 (NOLOCK) ON (ORDERS.Storerkey = CL2.Storerkey AND CL2.Listname='REPORTCFG' 
                                  AND CL2.Long = 'r_dw_delivery_note13') AND CL2.CODE = 'RemoveLogo'   
      --WL01 END
      WHERE ( ORDERS.Status = '9' ) AND     
            ( MBOL.Mbolkey = @c_Mbolkey )      
      GROUP BY --ORDERS.Storerkey, 
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN B.Storerkey 
                    ELSE A.Storerkey END ELSE ORDERS.STORERKEY END,    --mingle01
               SUBSTRING(ORDERS.ExternOrderKey,5,26),
               ORDERS.Route,
               ORDERS.Facility, 
               ORDERS.ConsigneeKey,   
               ORDERS.C_Company,   
               ORDERS.C_Address1,   
               ORDERS.C_Address2, 
               ORDERS.C_Address3,
               ORDERS.C_Address4,   
               ORDERS.C_City,
               ORDERS.C_Zip,
               ORDERS.C_Contact1,
               ORDERS.C_Contact2,
               ORDERS.C_Phone1,
               ORDERS.C_Phone2,
               --start --mingle01
               --ORDERS.BillToKey,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.BillToKey ELSE ORDERS.ConsigneeKey END 
                    ELSE ORDERS.BillToKey END,
               --ORDERS.B_Company,   
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Company ELSE B.Company END 
                    ELSE ORDERS.B_Company END,
               --ORDERS.B_Address1,  
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address1 ELSE B.Address1 END 
                    ELSE ORDERS.B_Address1 END,
               --ORDERS.B_Address2, 
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address2 ELSE B.Address2 END 
                    ELSE ORDERS.B_Address2 END,
               --ORDERS.B_Address3,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address3 ELSE B.Address3 END 
                    ELSE ORDERS.B_Address3 END,
               --ORDERS.B_Address4,  
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Address4 ELSE B.Address4 END 
                    ELSE ORDERS.B_Address4 END,
               --ORDERS.B_City,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_City ELSE B.City END 
                    ELSE ORDERS.B_City END,
               --ORDERS.B_Zip,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Zip ELSE B.Zip END 
                    ELSE ORDERS.B_Zip END,
               --ORDERS.B_Contact1,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Contact1 ELSE B.Contact1 END 
                    ELSE ORDERS.B_Contact1 END,
               --ORDERS.B_Contact2,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Contact2 ELSE B.Contact2 END 
                    ELSE ORDERS.B_Contact2 END,
               --ORDERS.B_Phone1,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Phone1 ELSE B.Phone1 END 
                    ELSE ORDERS.B_Phone1 END,
               --ORDERS.B_Phone2,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.StorerKey,'') = '' THEN ORDERS.B_Phone2 ELSE B.Phone2 END 
                    ELSE ORDERS.B_Phone2 END,
               --end --mingle01
               ORDERS.OrderKey,
               ORDERS.Adddate,
               ORDERS.DeliveryDate, 
               ORDERS.Salesman,
               ORDERS.BuyerPO, 
               ORDERDETAIL.SKU,
               SKU.DESCR,
               ORDERDETAIL.UOM,  
               LOTATTRIBUTE.Lottable02,
               LOTATTRIBUTE.Lottable04,
               C.Notes1,
               C.Notes2,
               SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),1,87),  
               SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),88,87),  
               SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),175,76),
               ISNULL(CODELKUP.Description,''),
               /* CASE WHEN ISNULL(CODELKUP.Notes,'') = '' THEN 'DELIVERY NOTE' ELSE CODELKUP.Notes END,*/
               CASE WHEN ISNULL(CODELKUP.Notes,'') = '' AND ORDERS.Type <> 'AXTO'  THEN 'DELIVERY NOTE' 
                    WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey <> '61280' THEN 'DELIVERY NOTE' 
                    WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey = '61280' THEN 'WAREHOUSE STOCK TRANSFER' 
                    ELSE CODELKUP.Notes END,
               ISNULL(CODELKUP.Code,''),
               --start  --mingle01
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Company ELSE A.Company END 
                    ELSE 'PT. IDS MEDICAL SYSTEMS INDONESIA' END,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address1 ELSE A.Address1 END 
                    ELSE 'WISMA 76 17TH FLOOR' END,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address2 ELSE A.Address2 END 
                    ELSE 'JL. LETJEND. S. PARMAN KAV. 76' END,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN (LTRIM(RTRIM(ISNULL(C.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(C.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(C.Country,''))))  
                                                     ELSE (LTRIM(RTRIM(ISNULL(A.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(A.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(A.Country,'')))) END 
                    ELSE 'SLIPI - JAKARTA 11410, INDONESIA' END,
               CASE WHEN ISNULL(CL1.SHORT,'N') = 'Y' THEN CASE WHEN ISNULL(A.Storerkey,'') = '' THEN ('Tel: ' + (LTRIM(RTRIM(ISNULL(C.Phone1,'')))) + ', ' + 'Fax: ' + TRIM(RTRIM(ISNULL(C.Fax1,'')))) 
                                                     ELSE ('Tel: ' + (LTRIM(RTRIM(ISNULL(A.Phone1,'')))) + ', ' + 'Fax: ' + LTRIM(RTRIM(ISNULL(A.Fax1,''))))  END 
                    ELSE 'TEL: +62 21 2567 8989, FAX: +62 21 5366 1038' END,
               --end    --mingle01
               ISNULL(CL2.Short,'N')   --WL01
   END
   
END -- procedure

GO