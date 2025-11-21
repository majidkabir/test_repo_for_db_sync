SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_delivery_note13a                                    */
/* Creation Date: 11-NOV-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14476 - IDSMED Delivery Note                            */
/*        :                                                             */
/* Called By: r_dw_delivery_note13a                                     */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note13a]
         @c_Mbolkey     NVARCHAR(10) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT, @c_Orderkey NVARCHAR(10), @c_SoldTo NVARCHAR(100), @c_Notes1 NVARCHAR(255)

   SET @n_continue = 1

   CREATE TABLE #TMP_DN (
   	Storerkey           NVARCHAR(30),
   	ExternOrderkey      NVARCHAR(50),
   	[ROUTE]             NVARCHAR(20),
   	Facility            NVARCHAR(10),
   	ConsigneeKey        NVARCHAR(30),
   	C_Company_1         NVARCHAR(100),
      C_Company_2         NVARCHAR(100),
      C_Company_3         NVARCHAR(100),
   	C_Address1          NVARCHAR(90),
   	C_Address2          NVARCHAR(90),
   	C_Address3          NVARCHAR(90),
   	C_Address4          NVARCHAR(90),
   	C_City              NVARCHAR(90),
   	C_Zip               NVARCHAR(36),
   	C_Contact1          NVARCHAR(60),
   	C_Contact2          NVARCHAR(60),
   	C_Phone1            NVARCHAR(36),
   	C_Phone2            NVARCHAR(36),
   	BillToKey           NVARCHAR(30),
   	B_Company_1         NVARCHAR(100),
      B_Company_2         NVARCHAR(100),
      B_Company_3         NVARCHAR(100),
   	B_Address1          NVARCHAR(90),
   	B_Address2          NVARCHAR(90),
   	B_Address3          NVARCHAR(90),
   	B_Address4          NVARCHAR(90),
   	B_City              NVARCHAR(90),
      B_Zip               NVARCHAR(36),
      B_Contact1          NVARCHAR(60),
      B_Contact2          NVARCHAR(60),
      B_Phone1            NVARCHAR(36),
      B_Phone2            NVARCHAR(36),
      OrderKey            NVARCHAR(20),
      Adddate             DATETIME,
      DeliveryDate        DATETIME,
      Salesman            NVARCHAR(60) ,
      BuyerPO             NVARCHAR(40) ,
      SKU                 NVARCHAR(40) ,
      DESCR               NVARCHAR(120),
      UOM                 NVARCHAR(20) ,
      Lottable02          NVARCHAR(36) ,
      Lottable04          DATETIME,
      Notes1              NVARCHAR(255),
      Notes2              NVARCHAR(255),
      Qty                 INT,
      NOTES1_1            NVARCHAR(255),
      NOTES1_2            NVARCHAR(255),
      NOTES1_3            NVARCHAR(255),
      CopyDesc            NVARCHAR(255),
      ReportTitle         NVARCHAR(255),
      [Copy]              NVARCHAR(60) ,
      company             NVARCHAR(90) ,
      address1            NVARCHAR(90) ,
      address2            NVARCHAR(90) ,
      address3            NVARCHAR(90) ,
      fax                 NVARCHAR(90) ,
      removelogo          NVARCHAR(10) ,
      StorerLogo          NVARCHAR(100)   --,
      --ShowStorerNotes     NVARCHAR(10) 
   )
      
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OH.Orderkey
   FROM MBOLDETAIL MD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON MD.Orderkey = OH.Orderkey
   WHERE MD.MBOLKey = @c_Mbolkey AND OH.[Status] = '9'
   
   OPEN CUR_LOOP
   	
   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	SELECT @c_SoldTo = CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) = 'BERSEDA' THEN ORDERS.Consigneekey ELSE ORDERS.BillToKey END
   	FROM ORDERS (NOLOCK)
   	WHERE OrderKey = @c_Orderkey
   	
   	SELECT @c_Notes1 = ISNULL(Storer.Notes1,'')
   	FROM STORER (NOLOCK)
   	WHERE StorerKey = @c_SoldTo
   	
   	INSERT INTO #TMP_DN
      SELECT CASE WHEN ISNULL(A.Storerkey,'') = '' THEN B.Storerkey ELSE A.Storerkey END,
             SUBSTRING(ORDERS.ExternOrderKey,5,26) AS ExternOrderkey,
             ORDERS.Route,
             ORDERS.Facility, 
             ORDERS.ConsigneeKey,   
             CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN SUBSTRING(LTRIM(S.Notes1),1, 45)   ELSE SUBSTRING(LTRIM(Orders.C_Company),1, 45)    END AS C_Company_1,
             CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN SUBSTRING(LTRIM(S.Notes1),46, 46)  ELSE SUBSTRING(LTRIM(Orders.C_Company),46, 46)   END AS C_Company_2,
             CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN SUBSTRING(LTRIM(S.Notes1),92, 125) ELSE SUBSTRING(LTRIM(Orders.C_Company),92, 125)  END AS C_Company_3,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address1 ELSE orders.C_Address1 END,   
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address2 ELSE orders.C_Address2 END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address3 ELSE orders.C_Address3 END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address4 ELSE orders.C_Address4 END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.City ELSE orders.C_City END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Zip ELSE orders.C_Zip END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Contact1 ELSE orders.C_Contact1 END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Contact2 ELSE orders.C_Contact2 END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Phone1 ELSE orders.C_Phone1 END,
             CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Phone2 ELSE orders.C_Phone2 END,
             --ORDERS.BillToKey,
             @c_SoldTo AS billtokey,
             --ORDERS.B_Company, 
             CASE WHEN ISNULL(@c_Notes1,'') <> '' THEN SUBSTRING(@c_Notes1,1,45) ELSE  
                  (CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN SUBSTRING(Orders.B_Company,1,45) ELSE SUBSTRING(S.B_Company,1,45) END)
             END AS b_company_1,
             CASE WHEN ISNULL(@c_Notes1,'') <> '' THEN SUBSTRING(@c_Notes1,46,46) ELSE  
                  (CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN SUBSTRING(Orders.B_Company,46,46) ELSE SUBSTRING(S.B_Company,46,46) END)
             END AS b_company_2,
             CASE WHEN ISNULL(@c_Notes1,'') <> '' THEN SUBSTRING(@c_Notes1,92,125) ELSE   
                  (CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN SUBSTRING(Orders.B_Company,92,125) ELSE SUBSTRING(S.B_Company,92,125) END)
             END AS b_company_3,
             --ORDERS.B_Address1,  
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address1 ELSE S.B_Address1 END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Address1 ELSE S.Address1 END)
             END AS b_address1, 
             --ORDERS.B_Address2, 
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address2 ELSE S.B_Address2 END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Address2 ELSE S.Address2 END)
             END AS b_address2,
             --ORDERS.B_Address3,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address3 ELSE S.B_Address3 END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Address3 ELSE S.Address3 END)
             END AS b_address3,
             --ORDERS.B_Address4,  
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address4 ELSE S.B_Address4 END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Address4 ELSE S.Address4 END)
             END AS b_address4,
             --ORDERS.B_City,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_City ELSE S.B_City END) ELSE
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_City ELSE S.City END)
             END AS b_city,
             --ORDERS.B_Zip,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Zip ELSE S.B_Zip END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Zip ELSE S.Zip END)
             END AS b_zip,
             --ORDERS.B_Contact1,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Contact1 ELSE S.B_Contact1 END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Contact1 ELSE S.Contact1 END)
             END AS b_contact1,
             --ORDERS.B_Contact2,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Contact2 ELSE S.B_Contact2 END) ELSE 
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Contact2 ELSE S.Contact2 END)
             END AS b_contact2,
             --ORDERS.B_Phone1,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Phone1 ELSE S.B_Phone1 END) ELSE   
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Phone1 ELSE S.Phone1 END)
             END AS b_phone1,
             --ORDERS.B_Phone2,
             CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Phone2 ELSE S.B_Phone2 END) ELSE
                  (CASE WHEN S.B_Address1 <> '' THEN S.B_Phone2 ELSE S.Phone2 END)
             END AS b_phone2,
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
             CASE WHEN ISNULL(CODELKUP.Notes,'') = '' AND ORDERS.Type <> 'AXTO'  THEN 'DELIVERY NOTE' 
                  WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey <> '61280' THEN 'DELIVERY NOTE' 
                  WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey = '61280' THEN 'WAREHOUSE STOCK TRANSFER' 
                  ELSE CODELKUP.Notes END AS ReportTitle,
             ISNULL(CODELKUP.Code,'') AS Copy,
             CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Company ELSE A.Company END, 
             CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address1 ELSE A.Address1 END,
             CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address2 ELSE A.Address2 END, 
             CASE WHEN ISNULL(A.Storerkey,'') = '' THEN (LTRIM(RTRIM(ISNULL(C.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(C.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(C.Country,''))))  
                                                   ELSE (LTRIM(RTRIM(ISNULL(A.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(A.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(A.Country,'')))) END,
             CASE WHEN ISNULL(A.Storerkey,'') = '' THEN ('Tel: ' + (LTRIM(RTRIM(ISNULL(C.Phone1,'')))) + ', ' + 'Fax: ' + TRIM(RTRIM(ISNULL(C.Fax1,'')))) 
                                                   ELSE ('Tel: ' + (LTRIM(RTRIM(ISNULL(A.Phone1,'')))) + ', ' + 'Fax: ' + LTRIM(RTRIM(ISNULL(A.Fax1,''))))  END, 
             ISNULL(CL2.Short,'N') AS RemoveLogo,
             CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Logo ELSE A.Logo END AS StorerLogo
      FROM ORDERS (NOLOCK)     
      JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey ) 
      JOIN PICKDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND    
                                  ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )  
      JOIN SKU (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) AND    
                            (SKU.Sku = ORDERDETAIL.Sku )     
      JOIN LOTATTRIBUTE (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot)     
      JOIN MBOL (NOLOCK) ON ( ORDERS.Mbolkey = MBOL.Mbolkey )    
      LEFT JOIN STORER S (NOLOCK) ON S.StorerKey = @c_SoldTo
      LEFT JOIN CODELKUP (NOLOCK) ON (ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname='REPORTCOPY' 
                                  AND CODELKUP.Long = 'r_dw_delivery_note13a')  
      LEFT JOIN STORER A (NOLOCK) ON A.StorerKey = ORDERS.IncoTerm                       
      JOIN STORER B (NOLOCK) ON B.Storerkey = CASE WHEN ISNULL(A.StorerKey,'') = '' THEN  ORDERS.Storerkey ELSE ORDERS.Consigneekey END           
      JOIN STORER C (NOLOCK) ON C.Storerkey = ORDERS.Storerkey  
      --LEFT JOIN CODELKUP AS CL1 (NOLOCK) ON (ORDERS.Storerkey = CL1.Storerkey AND CL1.Listname='REPORTCFG' 
      --                            AND CL1.Long = 'r_dw_delivery_note13a') AND CL1.CODE = 'ShowIncoTermInfo'
      LEFT JOIN CODELKUP AS CL2 (NOLOCK) ON (ORDERS.Storerkey = CL2.Storerkey AND CL2.Listname='REPORTCFG' 
                                  AND CL2.Long = 'r_dw_delivery_note13a') AND CL2.CODE = 'RemoveLogo'   
      WHERE ( ORDERS.Status = '9' ) AND     
            ( ORDERS.Orderkey = @c_Orderkey )      
      GROUP BY CASE WHEN ISNULL(A.Storerkey,'') = '' THEN B.Storerkey ELSE A.Storerkey END, 
               SUBSTRING(ORDERS.ExternOrderKey,5,26),
               ORDERS.Route,
               ORDERS.Facility, 
               ORDERS.ConsigneeKey,   
               CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN S.Notes1 ELSE Orders.C_Company END,
               CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN SUBSTRING(LTRIM(S.Notes1),1, 45)   ELSE SUBSTRING(LTRIM(Orders.C_Company),1, 45)    END,
               CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN SUBSTRING(LTRIM(S.Notes1),46, 46)  ELSE SUBSTRING(LTRIM(Orders.C_Company),46, 46)   END,
               CASE WHEN SUBSTRING(LTRIM(Orders.C_Company),1, 45) = SUBSTRING(LTRIM(S.Notes1),1, 45) THEN SUBSTRING(LTRIM(S.Notes1),92, 125) ELSE SUBSTRING(LTRIM(Orders.C_Company),92, 125)  END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address1 ELSE orders.C_Address1 END,   
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address2 ELSE orders.C_Address2 END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address3 ELSE orders.C_Address3 END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Address4 ELSE orders.C_Address4 END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.City ELSE orders.C_City END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Zip ELSE orders.C_Zip END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Contact1 ELSE orders.C_Contact1 END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Contact2 ELSE orders.C_Contact2 END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Phone1 ELSE orders.C_Phone1 END,
               CASE WHEN ISNULL(orders.C_Address1,'') = '' THEN S.Phone2 ELSE orders.C_Phone2 END,
               CASE WHEN ISNULL(@c_Notes1,'') <> '' THEN SUBSTRING(@c_Notes1,1,45) ELSE  
                    (CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN SUBSTRING(Orders.B_Company,1,45) ELSE SUBSTRING(S.B_Company,1,45) END)
               END,
               CASE WHEN ISNULL(@c_Notes1,'') <> '' THEN SUBSTRING(@c_Notes1,46,46) ELSE  
                    (CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN SUBSTRING(Orders.B_Company,46,46) ELSE SUBSTRING(S.B_Company,46,46) END)
               END,
               CASE WHEN ISNULL(@c_Notes1,'') <> '' THEN SUBSTRING(@c_Notes1,92,125) ELSE   
                    (CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN SUBSTRING(Orders.B_Company,92,125) ELSE SUBSTRING(S.B_Company,92,125) END)
               END,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address1 ELSE S.B_Address1 END) ELSE
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Address1 ELSE S.Address1 END)
               END, 
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address2 ELSE S.B_Address2 END) ELSE
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Address2 ELSE S.Address2 END)
               END,
               --ORDERS.B_Address3,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address3 ELSE S.B_Address3 END) ELSE
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Address3 ELSE S.Address3 END)
               END,
               --ORDERS.B_Address4,  
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Address4 ELSE S.B_Address4 END) ELSE
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Address4 ELSE S.Address4 END)
               END,
               --ORDERS.B_City,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_City ELSE S.B_City END) ELSE  
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_City ELSE S.City END)
               END,
               --ORDERS.B_Zip,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Zip ELSE S.B_Zip END) ELSE    
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Zip ELSE S.Zip END)
               END,
               --ORDERS.B_Contact1,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Contact1 ELSE S.B_Contact1 END) ELSE
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Contact1 ELSE S.Contact1 END)
               END,
               --ORDERS.B_Contact2,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Contact2 ELSE S.B_Contact2 END) ELSE
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Contact2 ELSE S.Contact2 END)
               END,
               --ORDERS.B_Phone1,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Phone1 ELSE S.B_Phone1 END) ELSE      
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Phone1 ELSE S.Phone1 END)
               END,
               --ORDERS.B_Phone2,
               CASE WHEN LTRIM(RTRIM(ISNULL(ORDERS.IncoTerm,''))) <>'BERSEDA' THEN (CASE WHEN orders.B_Address1 <> '' THEN Orders.B_Phone2 ELSE S.B_Phone2 END) ELSE      
                    (CASE WHEN S.B_Address1 <> '' THEN S.B_Phone2 ELSE S.Phone2 END)
               END,
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
               CASE WHEN ISNULL(CODELKUP.Notes,'') = '' AND ORDERS.Type <> 'AXTO'  THEN 'DELIVERY NOTE' 
                    WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey <> '61280' THEN 'DELIVERY NOTE' 
                    WHEN ORDERS.Type = 'AXTO' AND ORDERS.Storerkey = '61280' THEN 'WAREHOUSE STOCK TRANSFER' 
                    ELSE CODELKUP.Notes END,
               ISNULL(CODELKUP.Code,''),
               CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Company ELSE A.Company END, 
               CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address1 ELSE A.Address1 END,
               CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Address2 ELSE A.Address2 END, 
               CASE WHEN ISNULL(A.Storerkey,'') = '' THEN (LTRIM(RTRIM(ISNULL(C.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(C.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(C.Country,''))))  
                                                     ELSE (LTRIM(RTRIM(ISNULL(A.City,'')))) + ' ' + (LTRIM(RTRIM(ISNULL(A.Zip,'')))) + ', ' + (LTRIM(RTRIM(ISNULL(A.Country,'')))) END,
               CASE WHEN ISNULL(A.Storerkey,'') = '' THEN ('Tel: ' + (LTRIM(RTRIM(ISNULL(C.Phone1,'')))) + ', ' + 'Fax: ' + TRIM(RTRIM(ISNULL(C.Fax1,'')))) 
                                                     ELSE ('Tel: ' + (LTRIM(RTRIM(ISNULL(A.Phone1,'')))) + ', ' + 'Fax: ' + LTRIM(RTRIM(ISNULL(A.Fax1,''))))  END, 
               ISNULL(CL2.Short,'N'), CASE WHEN ISNULL(A.Storerkey,'') = '' THEN C.Logo ELSE A.Logo END
               
   	FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   SELECT * FROM #TMP_DN
   
   IF OBJECT_ID('tempdb..#TMP_DN') IS NOT NULL
      DROP TABLE #TMP_DN
      
END -- procedure

GO