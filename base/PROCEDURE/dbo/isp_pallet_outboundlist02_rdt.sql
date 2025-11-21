SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Pallet_outboundlist02_rdt                           */  
/* Creation Date: 17-May-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-9116 CN Fabory RDT print outbound list report CR        */  
/*        :                                                             */  
/* Called By: r_dw_pallet_outboundlist02_rdt                            */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 30/05/2019   WLChooi   1.0 WMS-9116 - Change logic                   */  
/* 12/07/2019   WLChooi   1.1 INC0774648 - Fix duplicated Qty issue     */  
/************************************************************************/  
CREATE PROC [dbo].[isp_Pallet_outboundlist02_rdt]  
           @c_PalletKey   NVARCHAR(30)  
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT = 1  
         , @c_PLTKey          NVARCHAR(30)  
         , @c_storerkey       NVARCHAR(20)  
         , @c_sku             NVARCHAR(20)    
         , @n_TTLCase         INT  
           
   SET @n_StartTCnt = @@TRANCOUNT  
     
   SET @n_TTLCase = 1  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   IF OBJECT_ID('tempdb..#TEMP_OBLIST2') IS NOT NULL  
      DROP TABLE #TEMP_OBLIST2  
     
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
   --WL02 Remark Start  
      --SELECT P.Palletkey  
      --      ,S.SKU  
      --      ,ROUND(P.Grosswgt,2) AS GrossWgt  
      --      ,P.Length  
      --      ,P.Width  
      --      ,P.Height  
      --      ,(SELECT SUM(QTY) FROM PACKDETAIL (NOLOCK) WHERE REFNO = P.PALLETKEY AND SKU = S.SKU AND QTY = PD.QTY) AS QTY  
      --      ,P.PalletType  
      --      ,S.StdGrossWgt  
      --      ,0 AS Netwgt  
      --      ,S.BUSR5  
      --      ,(SELECT COUNT(QTY) FROM PACKDETAIL (NOLOCK) WHERE REFNO = P.PALLETKEY AND SKU = S.SKU AND QTY = PD.QTY) AS Qty3  
      --      ,SUBSTRING( S.Sku, 1, 5 ) + '.' + SUBSTRING( S.Sku, 6, 3 ) + '.' + SUBSTRING( S.Sku, 9, 3 ) AS Code  
      --      ,LOT.LOTTABLE02  
      --      ,ORD.C_Company  
      --      ,CASE WHEN S.BUSR1 = 'Y' THEN   
      --       CASE WHEN ISNUMERIC(S.BUSR5) = 1 AND S.BUSR5 > 0 THEN PD.QTY / S.BUSR5 ELSE 0 END  
      --       ELSE 0 END AS 'BOXPerMOD'  
      --      ,CASE WHEN S.BUSR1 = 'Y' THEN 'Modulization' ELSE 'Non-conveyable' END AS Modulization  
      --      ,ORD.ExternOrderKey  
      --INTO #TEMP_OBLIST2  
      --FROM PALLET P(NOLOCK)   
      --JOIN PACKDETAIL PD (NOLOCK) ON PD.REFNO = P.PALLETKEY  
      --JOIN PACKHEADER PH (NOLOCK) ON PD.PICKSLIPNO = PH.PICKSLIPNO  
      --JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.STORERKEY = PD.STORERKEY  
      --JOIN ORDERS ORD (NOLOCK) ON ORD.Orderkey = PH.Orderkey  
      --JOIN ORDERDETAIL OD (NOLOCK) ON OD.ORDERKEY = ORD.ORDERKEY  
      --JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERLINENUMBER = OD.ORDERLINENUMBER AND PID.Orderkey = ORD.Orderkey   
      --                              AND PD.SKU = PID.SKU AND PD.DROPID = PID.PICKDETAILKEY AND PD.LabelNo = PID.ID  
      --JOIN LOTATTRIBUTE LOT (NOLOCK) ON LOT.LOT = PID.LOT --AND LOT.STORERKEY = PH.STORERKEY AND LOT.SKU = PD.SKU  
      --WHERE P.PALLETKEY = @c_PalletKey  
      --GROUP BY P.Palletkey  
      --        ,S.SKU  
      --        ,P.Grosswgt  
      --        ,P.Length  
      --        ,P.Width  
      --        ,P.Height  
      --        ,P.PalletType  
      --        ,S.StdGrossWgt  
      --        ,LOT.LOTTABLE02  
      --        ,S.BUSR5  
      --        ,ORD.C_Company  
      --        ,ORD.ExternOrderKey  
      --        ,S.BUSR1   
      --        ,PD.Qty  
      --        ,PH.Pickslipno  
      --      --  ,LOT.LOT  
      --ORDER BY S.SKU  
      --WL02 Remark END  
  
      --WL02 Start  
      SELECT DISTINCT   
              P.PalletKey  
            , PD.SKU  
            , ROUND(P.Grosswgt,2) AS GrossWgt  
            , P.Length  
            , P.Width  
            , P.Height  
            , SUM ( PD.Qty ) AS QTY  
            , P.PalletType  
            , S.STDGROSSWGT  
            , 0 AS NetWgt  
            , S.BUSR5  
            , Count (PD.Qty) AS Qty3  
            , SUBSTRING( PD.Sku, 1, 5 ) + '.' + SUBSTRING( PD.Sku, 6, 3 ) + '.' + SUBSTRING( PD.Sku, 9, 3 ) AS Code  
            , LOTT.Lottable02  
            , ORD.C_Company  
            , CASE WHEN S.BUSR1 = 'Y' THEN   
              CASE WHEN ISNUMERIC(S.BUSR5) = 1 AND S.BUSR5 > 0 THEN PD.QTY / S.BUSR5 ELSE 0 END  
              ELSE 0 END AS 'BOXPerMOD'  
            , CASE WHEN S.BUSR1 = 'Y' THEN 'Modulization' ELSE 'Non-conveyable' END AS Modulization  
            , ORD.ExternOrderKey  
      INTO #TEMP_OBLIST2  
      FROM ORDERS ORD (NOLOCK)   
      JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = ORD.OrderKey AND PH.StorerKey = ORD.StorerKey   
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno AND PD.StorerKey = PH.StorerKey  
      JOIN PICKDETAIL PID (NOLOCK) ON PID.Storerkey = PH.StorerKey AND PID.PickSlipNo = PH.PickSlipNo AND PD.DropID = PID.PickDetailKey  
                                  AND PD.DropID = PID.PickDetailKey   
      JOIN SKU S (NOLOCK) ON S.Sku = PD.SKU AND S.StorerKey = PD.StorerKey   
      JOIN PALLET P (NOLOCK) ON P.PalletKey = PD.RefNo AND P.StorerKey = PD.StorerKey  
      JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.StorerKey = PID.Storerkey AND PID.Lot = LOTT.Lot AND LOTT.Sku = PID.Sku  
      --WHERE (ORD.StorerKey='FABORY' AND ORD.Facility='FAB01' AND P.PalletKey = @c_PalletKey)  
      WHERE P.PalletKey = @c_PalletKey  
      GROUP BY ORD.ExternOrderKey  
             , P.PalletKey  
             , PD.SKU  
             , P.GrossWgt  
             , P.Length  
             , P.Width  
             , P.Height  
             , P.PalletType  
             , S.STDGROSSWGT  
             , S.BUSR5  
             , ORD.C_Company  
             , S.BUSR5  
             , S.BUSR1  
             , PID.Lot  
             , LOTT.Lottable02  
             , PD.Qty  
      --WL02 End  
   END  
  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
      SELECT Palletkey  
            ,SKU  
            ,Grosswgt  
            ,Length  
            ,Width  
            ,Height  
            ,Qty --SUM(Qty) AS Qty--(BUSR5 * BOXPerMod * Qty3) AS Qty   --WL02  
            ,PalletType  
            ,StdGrossWgt  
            ,NetWgt  
            ,BUSR5  
            ,CASE WHEN BOXPerMod > 0 THEN Qty3 ELSE 0 END AS Qty3  
            ,Code  
            ,Lottable02  
            ,C_Company  
            ,BOXPerMod  
            ,Modulization  
            ,ExternOrderKey  
      FROM #TEMP_OBLIST2  
      --GROUP BY Palletkey  
      --        ,SKU  
      --        ,Grosswgt  
      --        ,Length  
      --        ,Width  
      --        ,Height  
      --        ,PalletType  
      --        ,StdGrossWgt  
      --        ,NetWgt  
      --        ,BUSR5  
      --        ,CASE WHEN BOXPerMod > 0 THEN Qty3 ELSE 0 END  
      --        ,Code  
      --        ,Lottable02  
      --        ,C_Company  
      --        ,BOXPerMod  
      --        ,Modulization  
      --        ,ExternOrderKey  
      ORDER BY SKU  
  
   END  
  
  
END -- procedure  

GO