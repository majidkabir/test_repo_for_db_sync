SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PackListByCtn22_rdt                                 */  
/* Creation Date: 18-MAY-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  WMS-17022 - CN Taylormade DW Packing List for B2C          */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_by_ctn22_rdt                            */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_PackListByCtn22_rdt]    
     @c_PickSlipNo        NVARCHAR(10)
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

    SELECT --F.Descr
           LTRIM(RTRIM(ISNULL(ORD.C_Address1,'')))  AS C_Address1
          ,ORD.storerkey
          ,ORD.C_Company         
          ,LTRIM(RTRIM(ISNULL(ORD.C_Address2,'')))  AS C_Address2
          ,LTRIM(RTRIM(ISNULL(ORD.C_City,'')))      AS C_City
          ,CT.[cube] AS CBM 
          ,LTRIM(RTRIM(ISNULL(ORD.C_Country,'')))   AS C_Country
          ,ORD.Externorderkey
          ,ORD.BuyerPO
          ,CONVERT(NVARCHAR(10),GETDATE(),103) AS [GetDate]
        --  ,(SELECT (Count(Distinct(PD.labelno))) FROM PACKDETAIL PD(NOLOCK) WHERE PD.PICKSLIPNO = PH.PICKSLIPNO) AS TotalLabelNo    
         ,sku.MANUFACTURERSKU
         --, CT.CartonWeight    
          , PIF.Weight
          ,PD.Labelno
          ,PD.qty    
          ,sku.AltSKU
          ,LTRIM(RTRIM(ISNULL(F.Address1,''))) AS F_Add1
          ,LTRIM(RTRIM(ISNULL(F.Address2,''))) AS F_Add2
          ,LTRIM(RTRIM(ISNULL(SKU.Style,''))) AS style
          ,LTRIM(RTRIM(ISNULL(F.Address3,''))) AS F_Add3
          ,SKU.DESCR AS SKUDESCR
          ,LTRIM(RTRIM(ISNULL(F.Address4,''))) AS F_Add4
          ,SKU.color 
          ,SKU.SIZE 
          ,PD.SKU
          ,PD.CartonNo
          ,(SELECT MAX(CartonNo) FROM PACKDETAIL (NOLOCK) WHERE PICKSLIPNO = PH.PickSlipNo) AS MaxCartonNo
          , PIF.CartonType
          , ST.CartonGroup
    FROM ORDERS ORD (NOLOCK)
    JOIN FACILITY F WITH (NOLOCK) ON F.Facility=ORD.Facility
    --JOIN ORDERDETAIL OD (NOLOCK) ON ORD.Orderkey = OD.Orderkey
    --JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = OD.ORDERKEY AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER
    --                            AND PID.SKU = OD.SKU
    JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey=ORD.StorerKey
  --  JOIN LOTATTRIBUTE LOT (NOLOCK) ON PID.LOT = LOT.LOT
    JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
    JOIN PACKDETAIL PD (NOLOCK) ON PD.PICKSLIPNO = PH.PICKSLIPNO --AND PD.SKU = OD.SKU
    JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY
   -- CROSS APPLY (SELECT TOP 1 SKU.SUSR1 FROM SKU (NOLOCK) WHERE SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY) AS S
    --JOIN FACILITY F (NOLOCK) ON F.FACILITY = ORD.FACILITY
    JOIN PACKINFO PIF (NOLOCK) ON PIF.PICKSLIPNO = PH.PICKSLIPNO AND PIF.CARTONNO = PD.CARTONNO
    JOIN dbo.CARTONIZATION CT WITH (NOLOCK) ON CT.CartonizationGroup=ST.CartonGroup AND CT.CartonType = PIF.CartonType
    --OUTER APPLY (SELECT TOP 1 PODETAIL.USERDEFINE04 FROM PODETAIL (NOLOCK)
    --             WHERE LOT.LOTTABLE03 = PODETAIL.LOTTABLE03 AND PODETAIL.SKU = PD.SKU
    --             AND PODETAIL.STORERKEY = ORD.STORERKEY) AS POD
    
    WHERE PH.PICKSLIPNO = @c_PickSlipNo --'P000059529'
    GROUP BY ORD.StorerKey
            ,ORD.C_Company
            ,LTRIM(RTRIM(ISNULL(ORD.C_Address1,'')))
            ,LTRIM(RTRIM(ISNULL(ORD.C_Address2,'')))
            ,ISNULL(ORD.C_Address3,'')
            ,ORD.C_ZIP
            ,LTRIM(RTRIM(ISNULL(ORD.C_City,'')))
            ,ORD.C_State 
            ,LTRIM(RTRIM(ISNULL(ORD.C_Country,'')))
            ,ORD.Externorderkey
            ,ORD.BuyerPO
            ,PD.Labelno
            ,sku.MANUFACTURERSKU
            ,sku.AltSKU
          --  ,SKU.SUSR1
            ,LTRIM(RTRIM(ISNULL(SKU.Style,'')))
          -- ,ISNULL(POD.userdefine04,'')
            ,SKU.DESCR
            --,LOT.lottable08
            ,SKU.color 
            ,SKU.SIZE 
            ,PD.SKU
            ,PD.qty
            ,PH.PICKSLIPNO
          --  ,PIF.[WEIGHT]
            ,PD.CartonNo
            ,LTRIM(RTRIM(ISNULL(F.Address1,''))) 
            ,LTRIM(RTRIM(ISNULL(F.Address2,'')))
            ,LTRIM(RTRIM(ISNULL(F.Address3,''))) 
            ,LTRIM(RTRIM(ISNULL(F.Address4,'')))
          --  ,CT.CartonWeight
            , PIF.Weight
            ,PIF.CartonType
            ,ST.CartonGroup
           , CT.[Cube] 

QUIT_SP:  
END -- procedure  

GO