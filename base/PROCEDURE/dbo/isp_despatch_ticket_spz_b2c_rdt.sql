SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/**************************************************************************/  
/* Stored Procedure: isp_Despatch_Ticket_SPZ_B2C_RDT                      */  
/* Creation Date: 04-Nov-2020                                             */  
/* Copyright: LFL                                                         */  
/* Written by: WLChooi                                                    */  
/*                                                                        */  
/* Purpose: WMS-15452 - SPZ B2C Commercial Invoice                        */  
/*                                                                        */  
/* Called By: report dw = r_dw_Despatch_Ticket_SPZ_B2C_rdt                */  
/*                                                                        */  
/* GitLab Version: 1.3                                                    */  
/*                                                                        */  
/* Version: 5.4                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author    Ver.  Purposes                                  */  
/* 2021-06-15   WLChooi   1.1   WMS-17291 - Modify Logic and Add new      */
/*                              column (WL01)                             */
/* 2023-01-03   mingle    1.2   WMS-21381 - Add new col(ML01)             */
/* 06-Apr-2023  WLChooi   1.3   WMS-22159 Extend Userdefine01 to 50 (C01) */ 
/* 06-Apr-2023  WLChooi   1.3   DevOps Combine Script                     */ 
/**************************************************************************/  
CREATE   PROC [dbo].[isp_Despatch_Ticket_SPZ_B2C_RDT] (  
      @c_Pickslipno   NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey      NVARCHAR(10)
         , @n_ShowTerms     NVARCHAR(10)   --WL01
         , @n_ShowStamp     NVARCHAR(10)   --WL01
         , @c_Storerkey     NVARCHAR(15)   --WL01
   
   SET @c_Orderkey = @c_Pickslipno
   
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)
   BEGIN
      SELECT @c_Orderkey = OrderKey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END

   --WL01 S
   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE OrderKey = @c_Orderkey

   SELECT @n_ShowTerms  = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowTerms'  THEN 1 ELSE 0 END),
          @n_ShowStamp  = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowStamp'  THEN 1 ELSE 0 END)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Long = 'r_dw_Despatch_Ticket_SPZ_rdt'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Short = 'Y'
   AND CL.code2 = 'B2C'
   --WL01 E
   
   CREATE TABLE #TMP_SUM (
	      Orderkey              NVARCHAR(10) NULL
	    , UnitPricexQtyPicked   FLOAT        NULL
	    , QtyPicked             INT          NULL
       , Tax                   FLOAT        NULL )
       
   CREATE TABLE #TMP_RESULT (
   	   Externorderkey          NVARCHAR(50)  NULL
   	 , STCompany               NVARCHAR(45)  NULL
   	 , STNotes1                NVARCHAR(255) NULL
   	 , STAddress               NVARCHAR(500) NULL
   	 , STCountry               NVARCHAR(45)  NULL
   	 , C_Country               NVARCHAR(45)  NULL
   	 , OHUserDefine01          NVARCHAR(50)  NULL   --C01
   	 , C_Contact1              NVARCHAR(45)  NULL
   	 , C_Address1              NVARCHAR(45)  NULL
       , C_Address2              NVARCHAR(45)  NULL
       , C_Address3              NVARCHAR(45)  NULL
   	 , C_Phone1                NVARCHAR(45)  NULL
   	 , C_City                  NVARCHAR(500) NULL
   	 , Sku                     NVARCHAR(20)  NULL
   	 , DESCR                   NVARCHAR(60)  NULL
   	 , UserDefine01            NVARCHAR(18)  NULL
   	 , BUSR5                   NVARCHAR(30)  NULL
   	 , Lottable08              NVARCHAR(30)  NULL
   	 , UnitPrice               FLOAT NULL
   	 , QtyPicked               INT   NULL
   	 , ExtdValue               FLOAT NULL
   	 , SUMUnitPricexQtyPicked  NVARCHAR(20)  NULL
   	 , SUMQtyPicked            INT   NULL
   	 , UserDefine03            NVARCHAR(20)  NULL
   	 , TaxTitle                NVARCHAR(20)  NULL
   	 , SumTax                  FLOAT         NULL
   	 , Total                   NVARCHAR(255) NULL
   	 , M_Contact1              NVARCHAR(45)  NULL
       , M_Address1              NVARCHAR(45)  NULL
       , M_Address2              NVARCHAR(45)  NULL
       , M_Address3              NVARCHAR(45)  NULL
       , M_Address4              NVARCHAR(45)  NULL
       , M_City                  NVARCHAR(500) NULL
       , ODNotes2                NVARCHAR(500) NULL   --WL01
       , ShowStamp               NVARCHAR(10) NULL    --WL01
       , ShowTerms               NVARCHAR(10) NULL    --WL01
       , Terms                   NVARCHAR(10) NULL    --WL01
       , M_Contact2              NVARCHAR(100)  NULL	--ML01
       , M_Phone1                NVARCHAR(18)  NULL	--ML01
   )
   	 
   INSERT INTO #TMP_SUM (Orderkey, UnitPricexQtyPicked, QtyPicked, Tax)
   SELECT MAX(OH.Orderkey)
        , SUM(OD.UnitPrice * (OD.QtyPicked + OD.ShippedQty))
        , SUM(OD.QtyPicked + OD.ShippedQty)
        , SUM(OD.Tax01)
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   WHERE OH.Orderkey = @c_Orderkey
   --SELECT MAX(OH.Orderkey)
   --     , SUM(OD.UnitPrice * PD.Qty)
   --     , SUM(PD.Qty)
   --     , SUM(OD.Tax01)
   --FROM ORDERS OH (NOLOCK)
   --JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   --JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
   --                           AND OD.SKU = PD.SKU
   --WHERE OH.Orderkey = @c_Orderkey

   INSERT INTO #TMP_RESULT
   SELECT OH.Externorderkey
        , ISNULL(ST.Company,'') AS STCompany
        , ISNULL(ST.Notes1,'') AS STNotes1
        , TRIM(ISNULL(ST.Address1,'')) + ' ' + TRIM(ISNULL(ST.Address2,'')) + ' ' +
          TRIM(ISNULL(ST.Address3,'')) + ' ' + TRIM(ISNULL(ST.City,''))     + ' ' +
          TRIM(ISNULL(ST.[State],''))  + ' ' + TRIM(ISNULL(ST.Zip,''))      + ' ' + 
          TRIM(ISNULL(ST.Country,''))  + ' ' + TRIM(ISNULL(ST.Contact1,'')) AS STAddress
        , ISNULL(ST.Country,'') AS STCountry
        , ISNULL(OH.C_Country,'') AS C_Country
        , ISNULL(OH.UserDefine01,'') AS OHUserDefine01
        , ISNULL(OH.C_Company,'') AS C_Contact1   --WL01
        , ISNULL(OH.C_Address1,'') AS C_Address1
        , ISNULL(OH.C_Address2,'') AS C_Address2
        , ISNULL(OH.C_Address3,'') AS C_Address3
        , ISNULL(OH.C_Phone1,'') AS C_Phone1
        , CASE WHEN OH.C_City = NULL 
               THEN '(none)' 
               ELSE TRIM(ISNULL(OH.C_City,'')) + ' ' + TRIM(ISNULL(OH.C_State,'')) + ' ' + 
                    TRIM(ISNULL(OH.C_Country,'')) + ' ' + TRIM(ISNULL(OH.C_Zip,'')) END AS C_City
        , OD.Sku
        , S.DESCR
        , TRIM(OD.UserDefine01)
        , TRIM(ISNULL(S.BUSR5,'')) AS BUSR5
        , TRIM(ISNULL(LA.Lottable08,'')) AS Lottable08
        , OD.UnitPrice
        , (OD.QtyPicked + OD.ShippedQty)
        , ((OD.QtyPicked + OD.ShippedQty) * OD.UnitPrice) AS ExtdValue
        , '$' + CAST(FORMAT(t.UnitPricexQtyPicked,'##,###,##0.00') AS NVARCHAR(20)) AS SUMUnitPricexQtyPicked
        , t.QtyPicked AS SUMQtyPicked
        --, '$' + TRIM(ISNULL(OH.Userdefine03,''))
        , '$' + CASE WHEN ISNUMERIC(ISNULL(OH.Userdefine03,'')) = 1 THEN CAST(FORMAT(CAST(OH.Userdefine03 AS FLOAT),'##,###,##0.00') AS NVARCHAR(20)) ELSE TRIM(ISNULL(OH.Userdefine03,'')) END
        , TRIM(OD.Userdefine02) AS TaxTitle
        , t.Tax AS SumTax
        --WL01 S
        , CASE WHEN TRIM(OD.Userdefine02) LIKE '%incl%' 
               THEN '$' + CAST(FORMAT(t.UnitPricexQtyPicked +
                    CASE WHEN ISNUMERIC(OH.Userdefine03) = 1 
                         THEN CAST(OH.Userdefine03 AS FLOAT) 
                         ELSE 0 END,'##,###,##0.00') AS NVARCHAR(20))
               ELSE '$' + CAST(FORMAT(t.Tax + t.UnitPricexQtyPicked +
                    CASE WHEN ISNUMERIC(OH.Userdefine03) = 1 
                         THEN CAST(OH.Userdefine03 AS FLOAT) 
                         ELSE 0 END,'##,###,##0.00') AS NVARCHAR(20))
          END AS Total
        --WL01 E
        , ISNULL(OH.M_Company,'')  AS M_Contact1   --WL01
        , ISNULL(OH.M_Address1,'') AS M_Address1
        , ISNULL(OH.M_Address2,'') AS M_Address2
        , ISNULL(OH.M_Address3,'') AS M_Address3
        , ISNULL(OH.M_Address4,'') AS M_Address4
        , CASE WHEN OH.M_City = NULL 
               THEN '(none)' 
               ELSE TRIM(ISNULL(OH.M_City,'')) + ' ' + TRIM(ISNULL(OH.M_State,'')) + ' ' + 
                    TRIM(ISNULL(OH.M_Country,'')) + ' ' + TRIM(ISNULL(OH.M_Zip,'')) END AS M_City
        , CASE WHEN LEN(ISNULL(OH.Notes2,'')) > 1 THEN 'Notes: ' + TRIM(OH.Notes2) ELSE '' END   --WL01
        , @n_ShowStamp AS ShowStamp   --WL01
        , @n_ShowTerms AS ShowTerms   --WL01
        , CASE WHEN LEN(OH.IncoTerm) > 1 AND CAST(@n_ShowTerms AS NVARCHAR) = '1' THEN OH.IncoTerm ELSE '' END AS Terms   --WL01
        , ISNULL(OH.M_Contact2,'')  AS M_Contact2   --ML01
        , ISNULL(OH.M_Phone1,'')  AS M_Phone1   --ML01
   FROM ORDERS OH (NOLOCK)
   JOIN STORER ST (NOLOCK) ON OH.Storerkey = ST.StorerKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   LEFT JOIN StorerSODefault SSOD (NOLOCK) ON SSOD.StorerKey = OH.ConsigneeKey
   JOIN SKU S (NOLOCK) ON OD.Sku = S.Sku AND OD.StorerKey = S.StorerKey
   --JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
   --                           AND OD.SKU = PD.SKU
   CROSS APPLY (SELECT DISTINCT Pickdetail.Lot FROM PICKDETAIL (NOLOCK) 
                WHERE PICKDETAIL.OrderKey = OD.Orderkey AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber
                AND OD.SKU = PICKDETAIL.SKU) AS PD
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PD.Lot
   JOIN #TMP_SUM t (NOLOCK) ON t.Orderkey = OH.Orderkey
   WHERE OH.Orderkey = @c_Orderkey

   SELECT * FROM #TMP_RESULT
   ORDER BY Sku
   
   IF OBJECT_ID('tempdb..#TMP_SUM') IS NOT NULL
      DROP TABLE #TMP_SUM
   
   IF OBJECT_ID('tempdb..#TMP_RESULT') IS NOT NULL
      DROP TABLE #TMP_RESULT  

END

GO