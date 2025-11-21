SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PackListByCtn17_rdt                                 */  
/* Creation Date: 03-JUN-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose:  WMS-9285 - CN BoardRiders EMEA Packing List                */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_by_ctn17_rdt                            */  
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
CREATE PROC [dbo].[isp_PackListByCtn17_rdt]    
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
           S.SUSR1
          ,ORD.ConsigneeKey
          ,ORD.C_Company
          ,LTRIM(RTRIM(ISNULL(ORD.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,''))) 
           + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_Address3,''))) AS C_Addresses
          ,ORD.C_ZIP
          ,LTRIM(RTRIM(ISNULL(ORD.C_City,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORD.C_State,''))) AS CityState
          ,ORD.C_Country
          ,ORD.Externorderkey
          ,ORD.BuyerPO
          ,CONVERT(NVARCHAR(10),GETDATE(),103) AS [GetDate]
          ,(SELECT (Count(Distinct(PD.labelno))) FROM PACKDETAIL PD(NOLOCK) WHERE PD.PICKSLIPNO = PH.PICKSLIPNO) AS TotalLabelNo
          ,CAST(PIF.[WEIGHT] AS DECIMAL(10,2)) AS CartonWeight
          ,PD.Labelno
          ,PD.qty
          --,PD.Labelno
          --,Sum(SKU.STDGROSSWGT*PD.qty)
          ,SKU.RetailSKU
          ,OD.userdefine03 
          ,SKU.SUSR1
          ,LTRIM(RTRIM(ISNULL(SKU.Style,''))) + '-' +  LTRIM(RTRIM(ISNULL(SKU.Color,'')))
          ,ISNULL(POD.userdefine04,'') AS userdefine04
          ,SKU.DESCR AS SKUDESCR
          ,LOT.lottable08
          ,SKU.color 
          ,SKU.SIZE 
          ,SKU.SKU
          ,PD.CartonNo
          ,(SELECT MAX(CartonNo) FROM PACKDETAIL (NOLOCK) WHERE PICKSLIPNO = PH.PickSlipNo) AS MaxCartonNo
          ,(SELECT CAST(SUM([Weight])AS DECIMAL(10,2)) FROM PACKINFO (NOLOCK) WHERE PICKSLIPNO = PH.PickSlipNo) AS TotalWeight
    FROM ORDERS ORD (NOLOCK)
    JOIN ORDERDETAIL OD (NOLOCK) ON ORD.Orderkey = OD.Orderkey
    JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = OD.ORDERKEY AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER
                                AND PID.SKU = OD.SKU
    JOIN LOTATTRIBUTE LOT (NOLOCK) ON PID.LOT = LOT.LOT
    JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
    JOIN PACKDETAIL PD (NOLOCK) ON PD.PICKSLIPNO = PH.PICKSLIPNO AND PD.SKU = OD.SKU
    JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY
    CROSS APPLY (SELECT TOP 1 SKU.SUSR1 FROM SKU (NOLOCK) WHERE SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY) AS S
    --JOIN FACILITY F (NOLOCK) ON F.FACILITY = ORD.FACILITY
    JOIN PACKINFO PIF (NOLOCK) ON PIF.PICKSLIPNO = PH.PICKSLIPNO AND PIF.CARTONNO = PD.CARTONNO
    OUTER APPLY (SELECT TOP 1 PODETAIL.USERDEFINE04 FROM PODETAIL (NOLOCK)
                 WHERE LOT.LOTTABLE03 = PODETAIL.LOTTABLE03 AND PODETAIL.SKU = PD.SKU
                 AND PODETAIL.STORERKEY = ORD.STORERKEY) AS POD
    WHERE PH.PICKSLIPNO = @c_PickSlipNo --'P000059529'
    GROUP BY S.SUSR1 
           --F.Descr
            ,ORD.ConsigneeKey
            ,ORD.C_Company
            ,ISNULL(ORD.C_Address1,'')
            ,ISNULL(ORD.C_Address2,'')
            ,ISNULL(ORD.C_Address3,'')
            ,ORD.C_ZIP
            ,ORD.C_City
            ,ORD.C_State 
            ,ORD.C_Country
            ,ORD.Externorderkey
            ,ORD.BuyerPO
            ,PD.Labelno
            ,SKU.RetailSKU
            ,OD.userdefine03 
            ,SKU.SUSR1
            ,LTRIM(RTRIM(ISNULL(SKU.Style,''))) + '-' +  LTRIM(RTRIM(ISNULL(SKU.Color,'')))
            ,ISNULL(POD.userdefine04,'')
            ,SKU.DESCR
            ,LOT.lottable08
            ,SKU.color 
            ,SKU.SIZE 
            ,SKU.SKU
            ,PD.qty
            ,PH.PICKSLIPNO
            ,PIF.[WEIGHT]
            ,PD.CartonNo

QUIT_SP:  
END -- procedure  

GO