SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/**************************************************************************/  
/* Stored Procedure: isp_Despatch_Ticket_SPZ_B2B_RDT                      */  
/* Creation Date: 04-Nov-2020                                             */  
/* Copyright: LFL                                                         */  
/* Written by: WLChooi                                                    */  
/*                                                                        */  
/* Purpose: WMS-15452 - SPZ B2B Commercial Invoice                        */  
/*                                                                        */  
/* Called By: report dw = r_dw_Despatch_Ticket_SPZ_B2B_rdt                */  
/*                                                                        */  
/* GitLab Version: 1.3                                                    */  
/*                                                                        */  
/* Version: 5.4                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author    Ver.  Purposes                                  */  
/* 2021-01-18   WLChooi   1.1   INC1403544 - Return Blank Result if       */
/*                              ISOCntryCode = MY (WL01)                  */
/* 2021-06-15   WLChooi   1.2   WMS-17291 - Modify Logic (WL02)           */
/* 06-Apr-2023  WLChooi   1.3   WMS-22159 Extend Userdefine01 to 50 (C01) */ 
/* 06-Apr-2023  WLChooi   1.3   DevOps Combine Script                     */ 
/**************************************************************************/  
CREATE   PROC [dbo].[isp_Despatch_Ticket_SPZ_B2B_RDT] (  
      @c_Pickslipno   NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey      NVARCHAR(10),
           @c_Storerkey     NVARCHAR(15),
           @c_ISOCntryCode  NVARCHAR(10) = '',
           @n_ShowBrand     INT = 0,
           @n_ShowStamp     INT = 0,
           @n_ShowCOForm    INT = 0,
           @n_ShowCustom    INT = 0
   
   SET @c_Orderkey = @c_Pickslipno
   
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)
   BEGIN
      SELECT @c_Orderkey  = OrderKey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END
   
   SELECT @c_ISOCntryCode = ISNULL(ST.ISOCntryCode,'')
   FROM ORDERS OH (NOLOCK) 
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN StorerSODefault SSOD (NOLOCK) ON SSOD.StorerKey = OH.ConsigneeKey
   WHERE OH.OrderKey = @c_Orderkey AND SSOD.Destination <> 'EAST MALAYSIA'
   
   --WL01 Move Down
   --IF @c_ISOCntryCode = 'MY'
   --   GOTO QUIT_SP
   
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
   	SELECT @c_Storerkey = Storerkey
   	FROM ORDERS (NOLOCK)
   	WHERE OrderKey = @c_Orderkey
   END
   
   SELECT @n_ShowBrand  = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowBrand'  THEN 1 ELSE 0 END),
          @n_ShowStamp  = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowStamp'  THEN 1 ELSE 0 END),
          @n_ShowCOForm = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowCOForm' THEN 1 ELSE 0 END),
          @n_ShowCustom = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowCustom' THEN 1 ELSE 0 END)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Long = 'r_dw_Despatch_Ticket_SPZ_rdt'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Short = 'Y'
   AND CL.code2 = 'B2B'
   
   SELECT @n_ShowBrand  = ISNULL(@n_ShowBrand,0)
        , @n_ShowStamp  = ISNULL(@n_ShowStamp,0)
        , @n_ShowCOForm = ISNULL(@n_ShowCOForm,0)
        , @n_ShowCustom = ISNULL(@n_ShowCustom,0)
          
   --SELECT @n_ShowBrand  = 1
   --     , @n_ShowCOForm = 1
   --     , @n_ShowCustom = 1
   
   CREATE TABLE #TMP_SUM (
	      Orderkey              NVARCHAR(10)   NULL
	    , UnitPricexQtyPicked   FLOAT          NULL
	    , QtyPicked             INT            NULL
       , AmtInWords            NVARCHAR(1024) NULL
       , UOM                   NVARCHAR(10)   NULL)
       
   CREATE TABLE #TMP_RESULT (
   	   STCompany               NVARCHAR(45)  NULL
   	 , STNotes1                NVARCHAR(255) NULL
   	 , STAddress               NVARCHAR(500) NULL
   	 , Externorderkey          NVARCHAR(50)  NULL
   	 , BTAddress1              NVARCHAR(45)  NULL
   	 , BTAddress2              NVARCHAR(45)  NULL
   	 , BTAddress3              NVARCHAR(45)  NULL
   	 , BTCity                  NVARCHAR(255) NULL
   	 , BTCountry               NVARCHAR(45)  NULL
   	 , CSNAddress1             NVARCHAR(45)  NULL
   	 , CSNAddress2             NVARCHAR(45)  NULL
   	 , CSNAddress3             NVARCHAR(45)  NULL
   	 , CSNCity                 NVARCHAR(255) NULL
   	 , CSNCountry              NVARCHAR(45) NULL
   	 , SailingOn               NVARCHAR(100) NULL
   	 , Shipment                NVARCHAR(255) NULL
   	 , Via                     NVARCHAR(100) NULL
   	 , Terms                   NVARCHAR(30)  NULL
   	 , Sku                     NVARCHAR(20)  NULL
   	 , DESCR                   NVARCHAR(60)  NULL
   	 , ExternPOKey             NVARCHAR(20)  NULL
   	 , UserDefine01            NVARCHAR(18)  NULL
   	 , Lottable08              NVARCHAR(30)  NULL
   	 , BUSR5                   NVARCHAR(30)  NULL
   	 , BUSR6                   NVARCHAR(30)  NULL
   	 , QtyShip                 INT   NULL
   	 , UnitPrice               FLOAT NULL
   	 , ExtdValue               FLOAT NULL
   	 , OHUserDefine01          NVARCHAR(50) NULL   --C01
   	 , SUMUnitPricexQtyPicked  FLOAT NULL
   	 , SUMQtyPicked            INT NULL
   	 , AmtInWords              NVARCHAR(1024) NULL
   	 , STNotes2                NVARCHAR(255)  NULL
   	 , STSUSR1                 NVARCHAR(20)   NULL
   	 , BUSR7                   NVARCHAR(30)   NULL
   	 , MaxUOM                  NVARCHAR(10)   NULL 
       , ISOCntryCode            NVARCHAR(10)   NULL
       , ShowBrand               INT NULL
       , ShowStamp               INT NULL
       , ShowCOForm              INT NULL
       , ShowCustom              INT NULL
       , Lottable06              NVARCHAR(30)   NULL
       , Lottable07              NVARCHAR(30)   NULL)

   --WL01 S
   IF @c_ISOCntryCode = 'MY'
      GOTO QUIT_SP
   --WL01 E
      
   INSERT INTO #TMP_SUM (Orderkey, UnitPricexQtyPicked, QtyPicked, AmtInWords, UOM)
   SELECT MAX(OH.Orderkey)
        , SUM(OD.UnitPrice * PD.Qty)
        , SUM(PD.Qty)
        , UPPER((SELECT dbo.fnc_NumberToWords(SUM(OD.UnitPrice * PD.Qty),
                                              '',
                                              '',
                                              'CENTS',
                                              'ONLY'  ))) AS AmtInWords
        , MAX(OD.UOM)
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                              AND OD.SKU = PD.SKU
   WHERE OH.Orderkey = @c_Orderkey
   --SELECT MAX(OH.Orderkey)
   --     , SUM(OD.UnitPrice * PD.Qty)
   --     , SUM(PD.Qty)
   --     , UPPER((SELECT dbo.fnc_NumberToWords(SUM(OD.UnitPrice * PD.Qty),
   --                                           '',
   --                                           '',
   --                                           '',
   --                                           'ONLY'))) AS AmtInWords
   --     , MAX(OD.UOM)
   --FROM ORDERS OH (NOLOCK)
   --JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   --JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
   --                           AND OD.SKU = PD.SKU
   --WHERE OH.Orderkey = @c_Orderkey
   
   INSERT INTO #TMP_RESULT
   SELECT 
          ISNULL(ST.Company,'') AS STCompany
        , ISNULL(ST.Notes1,'') AS STNotes1
        , TRIM(ISNULL(ST.Address1,'')) + ' ' + TRIM(ISNULL(ST.Address2,'')) + ' ' +
          TRIM(ISNULL(ST.Address3,'')) + ' ' + TRIM(ISNULL(ST.City,''))     + ' ' +
          TRIM(ISNULL(ST.[State],''))  + ' ' + TRIM(ISNULL(ST.Zip,''))      + ' ' + 
          TRIM(ISNULL(ST.Country,''))  + ' ' + TRIM(ISNULL(ST.Contact1,'')) AS STAddress
        , OH.Externorderkey
        , ISNULL(OH.B_Address1,'') AS BTAddress1
        , ISNULL(OH.B_Address2,'') AS BTAddress2
        , ISNULL(OH.B_Address3,'') AS BTAddress3
        , TRIM(ISNULL(OH.B_City,'')) + ' ' + TRIM(ISNULL(OH.B_State,'')) + ' ' + 
          TRIM(ISNULL(OH.B_Zip,'')) AS BTCity
        , ISNULL(OH.B_Country,'') AS BTCountry
        , ISNULL(OH.C_Address1,'') AS CSNAddress1
        , ISNULL(OH.C_Address2,'') AS CSNAddress2
        , ISNULL(OH.C_Address3,'') AS CSNAddress3
        , TRIM(ISNULL(OH.C_City,''))    + ' ' + TRIM(ISNULL(OH.C_State,'')) + ' ' + 
          TRIM(ISNULL(OH.C_Country,'')) + ' ' + TRIM(ISNULL(OH.C_Zip,'')) AS CSNCity
        , ISNULL(OH.C_Country,'') AS CSNCountry
        , '' AS SailingOn
        , TRIM(ISNULL(ST.Country,'')) + ' to ' + TRIM(ISNULL(OH.C_Country,'')) AS Shipment
        , '' AS Via
        , CASE WHEN LEN(ISNULL(OH.IncoTerm,'')) > 1 THEN ISNULL(OH.IncoTerm,'') ELSE ISNULL(SSOD.Terms,'') END AS Terms   --ISNULL(SSOD.Terms,'') AS Terms   --WL02
        , TRIM(OD.Sku)
        , TRIM(S.DESCR)
        , TRIM(OD.ExternPOKey)
        , TRIM(OD.UserDefine01)
        , ISNULL(LA.Lottable08,'') AS Lottable08
        , TRIM(ISNULL(S.BUSR5,'')) AS BUSR5
        , CASE WHEN @n_ShowBrand = 1 THEN ISNULL(S.BUSR6,'') ELSE '' END AS BUSR6
        --, CAST(PD.Qty AS NVARCHAR(10)) + ' ' + OD.UOM AS QtyShip
        , PD.Qty AS QtyShip
        , OD.UnitPrice
        , (PD.Qty * OD.UnitPrice) AS ExtdValue
        , TRIM(ISNULL(OH.UserDefine01,'')) AS OHUserDefine01
        , t.UnitPricexQtyPicked AS SUMUnitPricexQtyPicked
        , t.QtyPicked AS SUMQtyPicked
        , t.AmtInWords AS AmtInWords
        , ISNULL(ST.Notes2,'') AS STNotes2
        , ISNULL(ST.SUSR1,'') AS STSUSR1
        , CASE WHEN @n_ShowCOForm = 1 THEN ISNULL(S.BUSR7,'') ELSE '' END AS BUSR7
        , t.UOM AS MaxUOM
        , ST.ISOCntryCode
        , @n_ShowBrand AS ShowBrand
        , @n_ShowStamp AS ShowStamp
        , @n_ShowCOForm AS ShowCOForm
        , @n_ShowCustom AS ShowCustom
        , ISNULL(LA.Lottable06,'') AS Lottable06
        , ISNULL(LA.Lottable07,'') AS Lottable07
   FROM ORDERS OH (NOLOCK)
   JOIN STORER ST (NOLOCK) ON OH.Storerkey = ST.StorerKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   LEFT JOIN StorerSODefault SSOD (NOLOCK) ON SSOD.StorerKey = OH.ConsigneeKey
   JOIN SKU S (NOLOCK) ON OD.Sku = S.Sku AND OD.StorerKey = S.StorerKey
   JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                              AND OD.SKU = PD.SKU
   --CROSS APPLY (SELECT DISTINCT MAX(Pickdetail.Lot) AS Lot, SUM(Pickdetail.Qty) AS Qty  FROM PICKDETAIL (NOLOCK) 
   --             WHERE PICKDETAIL.OrderKey = OD.Orderkey AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber
   --             AND OD.SKU = PICKDETAIL.SKU) AS PD
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PD.Lot
   JOIN #TMP_SUM t (NOLOCK) ON t.Orderkey = OH.Orderkey
   WHERE OH.Orderkey = @c_Orderkey

QUIT_SP:   --WL01
   SELECT  STCompany             
         , STNotes1              
         , STAddress             
         , Externorderkey        
         , BTAddress1            
         , BTAddress2            
         , BTAddress3            
         , BTCity                
         , BTCountry             
         , CSNAddress1           
         , CSNAddress2           
         , CSNAddress3           
         , CSNCity               
         , CSNCountry            
         , SailingOn             
         , Shipment              
         , Via                   
         , Terms                 
         , Sku                   
         , DESCR                 
         , ExternPOKey           
         , UserDefine01          
         , Lottable08            
         , BUSR5                 
         , BUSR6                 
         , SUM(QtyShip) AS QtyShip            
         , UnitPrice             
         , SUM(ExtdValue) AS ExtdValue          
         , OHUserDefine01        
         , SUMUnitPricexQtyPicked
         , SUMQtyPicked          
         , AmtInWords            
         , STNotes2              
         , STSUSR1               
         , BUSR7                 
         , MaxUOM                
         , ISOCntryCode          
         , ShowBrand             
         , ShowStamp             
         , ShowCOForm            
         , ShowCustom            
         , Lottable06            
         , Lottable07            
   FROM #TMP_RESULT
   GROUP BY  STCompany             
         , STNotes1              
         , STAddress             
         , Externorderkey        
         , BTAddress1            
         , BTAddress2            
         , BTAddress3            
         , BTCity                
         , BTCountry             
         , CSNAddress1           
         , CSNAddress2           
         , CSNAddress3           
         , CSNCity               
         , CSNCountry            
         , SailingOn             
         , Shipment              
         , Via                   
         , Terms                 
         , Sku                   
         , DESCR                 
         , ExternPOKey           
         , UserDefine01          
         , Lottable08            
         , BUSR5                 
         , BUSR6                 
         --, QtyShip               
         , UnitPrice             
         --, ExtdValue             
         , OHUserDefine01        
         , SUMUnitPricexQtyPicked
         , SUMQtyPicked          
         , AmtInWords            
         , STNotes2              
         , STSUSR1               
         , BUSR7                 
         , MaxUOM                
         , ISOCntryCode          
         , ShowBrand             
         , ShowStamp             
         , ShowCOForm            
         , ShowCustom            
         , Lottable06            
         , Lottable07 
   ORDER BY Sku
   
--QUIT_SP:   --WL01 Move Up
   IF OBJECT_ID('tempdb..#TMP_SUM') IS NOT NULL
      DROP TABLE #TMP_SUM
   
   IF OBJECT_ID('tempdb..#TMP_RESULT') IS NOT NULL
      DROP TABLE #TMP_RESULT  

END

GO