SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_RPT_ORD_DELNOTECTN_004                            */  
/* Creation Date: 10-Jan-2023                                              */  
/* Copyright: LFL                                                          */  
/* Written by: WLChooi                                                     */  
/*                                                                         */  
/* Purpose: WMS-21493 - ID-PUMA-Delivery Note                              */  
/*                                                                         */  
/* Called By: RPT_ORD_DELNOTECTN_004                                       */  
/*                                                                         */  
/* GitLab Version: 1.0                                                     */  
/*                                                                         */  
/* Version: 1.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 10-Jan-2023  WLChooi 1.0   DevOps Combine Script                        */ 
/* 16-Jun-2023  WLChooi 1.1   WMS-22878 - Change column mapping (WL01)     */
/***************************************************************************/  
CREATE   PROC [dbo].[isp_RPT_ORD_DELNOTECTN_004] @c_Orderkey NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Success   INT  
         , @n_Err       INT  
         , @n_Continue  INT  
         , @n_StartTCnt INT  
         , @c_ErrMsg    NVARCHAR(250);  
  
   WITH ctePickDetail AS  
   (  
      SELECT PD.Storerkey  
           , PD.OrderKey  
           , PD.PickSlipNo  
           , PD.Sku  
           , SUM(PD.Qty) [Qty]  
      FROM ORDERDETAIL OD (NOLOCK)  
      JOIN PICKDETAIL PD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber  
      WHERE PD.OrderKey = @c_Orderkey  
      GROUP BY PD.Storerkey  
             , PD.OrderKey  
             , PD.PickSlipNo  
             , PD.Sku  
   )  
      , cteSumBySKUGroup AS  
   (  
      SELECT S.SKUGROUP  
           , SUM(CPD.Qty) [DivQty]  
           , SUM(CPD.Qty * S.STDGROSSWGT) [DivWeight]  
           , SUM(CPD.Qty * S.STDCUBE) [DivVol]  
      FROM ctePickDetail CPD  
      JOIN SKU S (NOLOCK) ON CPD.Storerkey = S.StorerKey AND CPD.Sku = S.Sku  
      GROUP BY CPD.OrderKey  
             , S.SKUGROUP  
   )  
      , ctePackDetail AS  
   (  
      SELECT PAD.StorerKey  
           , CPD.OrderKey  
           , PAD.PickSlipNo  
           , PAD.DropID [LabelNo]   --WL01
           , S.Style [Article]  
           , MAX(S.DESCR) [Description]  
           , P.PackUOM3 [UOM]  
           , SUM(PAD.Qty) [Qty]  
           , STRING_AGG(S.Size + '/' + CONVERT(NVARCHAR(MAX), PAD.Qty), ', ')WITHIN GROUP(ORDER BY S.Size) [Size/Qty]  
           , S.SKUGROUP  
           , DV.DivQty  
           , DV.DivWeight  
           , DV.DivVol  
      FROM ctePickDetail CPD  
      JOIN PackDetail PAD (NOLOCK) ON  CPD.Storerkey = PAD.StorerKey  
                                   AND CPD.PickSlipNo = PAD.PickSlipNo  
                                   AND CPD.Sku = PAD.SKU  
      JOIN SKU S (NOLOCK) ON CPD.Storerkey = S.StorerKey AND CPD.Sku = S.Sku  
      JOIN PACK P (NOLOCK) ON S.PACKKey = P.PackKey  
      JOIN cteSumBySKUGroup DV ON S.SKUGROUP = DV.SKUGROUP  
      GROUP BY PAD.StorerKey  
             , CPD.OrderKey  
             , PAD.PickSlipNo  
             , PAD.DropID   --WL01  
             , S.SKUGROUP  
             , DV.DivQty  
             , DV.DivWeight  
             , DV.DivVol  
             , S.Style  
             , P.PackUOM3  
   )  
   SELECT O.OrderKey  
        , O.UserDefine09 [CustOrderNo]  
        , O.UserDefine05 [SalesOrderNo]  
        , O.DeliveryDate [DeliveryDate]  
        , O.ExternOrderKey [DeliveryNote]  
        , O.ConsigneeKey [CustomerNumber]  
        , O.C_Company [ShipToName]  
        , CASE WHEN ISNULL(O.C_Address1, '') <> '' THEN O.C_Address1 + CHAR(10)  
               ELSE '' END + CASE WHEN ISNULL(O.C_Address2, '') <> '' THEN O.C_Address2 + CHAR(10)  
                                  ELSE '' END + CASE WHEN ISNULL(O.C_Address3, '') <> '' THEN O.C_Address3 + CHAR(10)  
                                                     ELSE '' END  
          + CASE WHEN ISNULL(O.C_City, '') <> '' THEN O.C_City + ' '  
                 ELSE '' END + CASE WHEN ISNULL(O.C_Zip, '') <> '' THEN O.C_Zip + CHAR(10)  
                                    ELSE '' END AS [Address]  
        , M.EditDate [DocumentDate]  
        , M.Carrieragent [Forwarder]  
        , PAH.TTLCNTS [CartonQty]  
        , PAH.TotCtnWeight [Weight]  
        , PAH.TotCtnCube [Vol]  
        , CPAD.LabelNo  
        , CPAD.Article  
        , CPAD.Description  
        , CPAD.UOM [Unit]  
        , CPAD.Qty  
        , CPAD.[Size/Qty]  
        , CPAD.SKUGROUP  
        , CPAD.DivQty  
        , CPAD.DivWeight  
        , CPAD.DivVol  
   FROM ctePackDetail CPAD  
   JOIN ORDERS O (NOLOCK) ON CPAD.OrderKey = O.OrderKey  
   LEFT JOIN MBOL M (NOLOCK) ON O.MBOLKey = M.MbolKey  
   LEFT JOIN PackHeader PAH (NOLOCK) ON CPAD.PickSlipNo = PAH.PickSlipNo AND CPAD.OrderKey = PAH.OrderKey  
  
END

GO