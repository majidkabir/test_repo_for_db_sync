SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PackListByCtn18_rdt                                 */  
/* Creation Date: 03-JUN-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose:  WMS-9311 - CN - BoardRiders -BRAU Packing List             */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_by_ctn18_rdt                            */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 00-MAR-2023  CSCHONG   1.1 Devops Scripts Combine & WMS-21892 (CS01) */
/* 28-MAR-2023  CSCHONG   1.2 WMS-21892 (CS02)                          */
/************************************************************************/  
CREATE   PROC [dbo].[isp_PackListByCtn18_rdt]    
     @c_PickSlipNo        NVARCHAR(10)--,
   --  @c_Type              NVARCHAR(1) = '',
  --   @c_PageNo            NVARCHAR(10) = ''
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt             INT  
         , @n_Continue              INT
         , @c_Storerkey             NVARCHAR(20)  
         
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   
--   IF OBJECT_ID('tempdb..#TEMP_CTN18 ','u') IS NOT NULL 
 --     DROP TABLE #TEMP_CTN18
   
   SELECT --ORD.M_Company 
           'Ug Mfg Co Pty Ltd ABN 63 005 047 941'
          ,'' 
          ,'PO Box 138 Turquay, Vic 3228, Australia'
          --,LTRIM(RTRIM(ISNULL(ORD.M_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.M_Address2,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.M_City,'')))
          -- + LTRIM(RTRIM(ISNULL(ORD.M_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.M_Zip,''))) AS M_Addresses
          --,ISNULL(CL.UDF01,'') AS UDF01 
          --,ISNULL(CL.UDF02,'') AS UDF02 
          ,'Tel: 03 52616000 / Toll Free: 1800 805 506'
          ,'Fax: 03 52615600 / www.quiksilver.com'
          ,ORD.Externorderkey
          ,CONVERT(NVARCHAR(10),GETDATE(),103) AS TodayDate
          ,ORD.Ordergroup 
          ,PD.qty AS Qty
          ,(SELECT (Count(Distinct(PD.labelno))) FROM PACKDETAIL PD(NOLOCK) WHERE PD.PICKSLIPNO = PH.PICKSLIPNO) AS TotalLabelNo
          --,CAST(SKU.STDGROSSWGT * PD.qty AS DECIMAL(10,2)) AS Grosswgt --SKU.STDGROSSWGT AS GrossWgt 
          ,CAST(PIF.[WEIGHT] AS DECIMAL(10,2)) AS CartonWeight
          ,CASE WHEN LTRIM(RTRIM(ISNULL(CL2.UDF04,''))) <> '' THEN LTRIM(RTRIM(ISNULL(CL2.UDF04,''))) + RIGHT(LTRIM(RTRIM(ORD.ExternOrderKey)),7) 
                 ELSE CASE WHEN ISNULL(cT.CarrierRef2,'') <> '' THEN ISNULL(cT.CarrierRef2,'') ELSE RIGHT(LTRIM(RTRIM(ORD.ExternOrderKey)),7) END END AS CsgnmNotes   --CS01
          ,ORD.BillTokey
          ,ORD.B_Company
          ,LTRIM(RTRIM(ISNULL(ORD.B_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.B_Address2,''))) AS B_Addresses
          ,LTRIM(RTRIM(ISNULL(ORD.B_City,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.B_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.B_Zip,''))) AS BCityStateZip
          ,ORD.M_Country     
          ,ORD.ConsigneeKey
          ,ORD.C_Company 
          ,LTRIM(RTRIM(ISNULL(ORD.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,''))) AS C_Addresses
          ,LTRIM(RTRIM(ISNULL(ORD.C_City,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_Zip,''))) AS CCityStateZip
          ,ORD.C_Country     
          ,PD.cartonno
          ,ORD.BuyerPO
          ,SKU.Style
          ,SKU.Color
          ,SKU.DESCR AS SKUDESCR
          ,SKU.Size
          ,ORDET.ExtendedPrice
          --,LOT.Lottable03
          ,ORDET.UnitPrice
          ,ORDET.Tax01
          ,CASE WHEN LTRIM(RTRIM(ISNULL(OI.OrderInfo04,''))) = 'PL_AU_PRICE' THEN '1'
                WHEN LTRIM(RTRIM(ISNULL(OI.OrderInfo04,''))) = 'PL_AU_NOPRICE' THEN '2'
                ELSE '' END AS OrderInfo04
          ,(SELECT CAST(SUM([Weight])AS DECIMAL(10,2)) FROM PACKINFO (NOLOCK) WHERE PICKSLIPNO = PH.PickSlipNo) AS TotalWeight
          ,MAX(OD.UserDefine05) AS UserDefine05
  --  INTO #TEMP_CTN18
    FROM ORDERS ORD (NOLOCK)
    JOIN ORDERDETAIL OD (NOLOCK) ON ORD.Orderkey = OD.Orderkey
    --JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = OD.ORDERKEY AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER
    --                            AND PID.SKU = OD.SKU
    --JOIN LOTATTRIBUTE LOT (NOLOCK) ON PID.LOT = LOT.LOT
    JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
    JOIN PACKDETAIL PD (NOLOCK) ON PD.PICKSLIPNO = PH.PICKSLIPNO AND PD.SKU = OD.SKU
    JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY
    JOIN PACKINFO PIF (NOLOCK) ON PIF.PICKSLIPNO = PH.PICKSLIPNO AND PIF.CARTONNO = PD.CARTONNO
    --LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'BBGBrand' AND CL.STORERKEY = PH.STORERKEY AND CL.CODE = ORD.UserDefine03
    --                              AND CL.CODE2 = ORD.OrderGroup
    LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.STORERKEY = PH.STORERKEY AND CL2.LISTNAME = 'BRToll' AND CL2.Code = ORD.Shipperkey
    LEFT JOIN ORDERINFO OI (NOLOCK) ON OI.OrderKey = ORD.OrderKey
    CROSS APPLY ( SELECT TOP 1 UnitPrice, Tax01, ExtendedPrice
                  FROM ORDERDETAIL ORDET (NOLOCK) WHERE ORDET.SKU = PD.SKU AND ORDET.ORDERKEY = PH.ORDERKEY) AS ORDET
    --CS01 S
     OUTER APPLY (SELECT DISTINCT labelno , CarrierRef2 FROM dbo.CartonTrack CTR WITH (NOLOCK) WHERE CTR.LabelNo = PD.labelno) CT
    --CS01 E
    WHERE PH.PICKSLIPNO = @c_PickSlipNo --'P000058729'
    GROUP BY --ORD.M_Company 
          --,ORD.MarkforKey    
          --,LTRIM(RTRIM(ISNULL(ORD.M_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.M_Address2,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.M_City,'')))
          -- + LTRIM(RTRIM(ISNULL(ORD.M_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.M_Zip,'')))
          --,ISNULL(CL.UDF01,'')
          --,ISNULL(CL.UDF02,'') 
   --        ORD.Externorderkey
           ORD.Ordergroup 
          ,PD.qty
          ,PH.PICKSLIPNO
          ,PD.LabelNo
          ,PIF.[WEIGHT]
          ,ORD.Externorderkey
          ,ORD.BillTokey
          ,ORD.B_Company
          ,LTRIM(RTRIM(ISNULL(ORD.B_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.B_Address2,'')))
          ,LTRIM(RTRIM(ISNULL(ORD.B_City,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.B_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.B_Zip,'')))
          ,ORD.M_Country     
          ,ORD.ConsigneeKey
          ,ORD.C_Company 
          ,LTRIM(RTRIM(ISNULL(ORD.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,'')))
          ,LTRIM(RTRIM(ISNULL(ORD.C_City,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_Zip,'')))
          ,ORD.C_Country     
          ,PD.cartonno
          ,ORD.BuyerPO
          ,SKU.Style
          ,SKU.Color
          ,SKU.DESCR
          ,SKU.Size
          ,ORDET.ExtendedPrice
          --,LOT.Lottable03
          ,ISNULL(CL2.UDF04,'')
          ,ORDET.UnitPrice
          ,ORDET.Tax01
          ,CASE WHEN LTRIM(RTRIM(ISNULL(OI.OrderInfo04,''))) = 'PL_AU_PRICE' THEN '1'
                WHEN LTRIM(RTRIM(ISNULL(OI.OrderInfo04,''))) = 'PL_AU_NOPRICE' THEN '2'
                ELSE '' END
          ,ISNULL(cT.CarrierRef2,'')     --CS01
  ORDER BY PD.CartonNo
  
  --SELECT * FROM #TEMP_CTN18 ORDER BY CartonNo

QUIT_SP:  
END -- procedure  

GO