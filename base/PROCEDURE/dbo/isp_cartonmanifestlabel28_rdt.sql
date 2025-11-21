SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/                
/* Store Procedure: isp_CartonManifestLabel28_rdt                             */                
/* Creation Date: 04-Dec-2019                                                 */                
/* Copyright: LFL                                                             */                
/* Written by: WLChooi                                                        */                
/*                                                                            */                
/* Purpose: WMS-11264 - Convert to call SP                                    */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_dw_carton_manifest_label_28_rdt                              */                
/*                                                                            */                
/* PVCS Version: 1.0                                                          */                
/*                                                                            */                
/* Version: 1.0                                                               */                
/*                                                                            */                
/* Data Modifications:                                                        */                
/*                                                                            */                
/* Updates:                                                                   */                
/* Date         Author    Ver.  Purposes                                      */      
/******************************************************************************/       
    
CREATE PROC [dbo].[isp_CartonManifestLabel28_rdt]               
       (@c_StorerKey NVARCHAR(15),
        @c_DropID    NVARCHAR(20) )                
AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_WARNINGS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue        INT = 1
         , @c_orderkey        NVARCHAR(20) = ''
         , @n_sumqty          INT = 0 
         , @c_Lott07          NVARCHAR(40) = ''
         , @c_sku             NVARCHAR(40) = ''
         , @c_Palletkey       NVARCHAR(60) = ''
         , @c_PGrossWeight    FLOAT = 0.00
         , @c_CBM             FLOAT = 0.00
         , @n_LineNumber      INT = 10

   SELECT PACKHEADER.PickSlipNo,
          PACKHEADER.OrderRefNo,
          PACKDETAIL.LabelNo,
          PACKDETAIL.CartonNo,
          PACKDETAIL.Sku, 
          (SELECT ISNULL(MAX(P2.CartonNo), 0) 
           FROM PACKDETAIL P2 (NOLOCK) 
           WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo
           AND P2.storerkey = @c_StorerKey           /* WMS-5833 */	
           HAVING SUM(P2.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)
                                 WHERE OD2.OrderKey = PACKHEADER.OrderKey) ) as CartonMax,
           LabelQty.TotQty as TotalQty,
          SUM(PACKDETAIL.Qty) as Qty,
          CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + ' ' + CONVERT(CHAR(8), GetDate(), 108)) as PrintDate,
          ORDERS.UserDefine04,
          (SELECT COUNT(DISTINCT P.Orderkey)
           FROM PACKHEADER P (NOLOCK) 
           JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = P.Pickslipno        /* WMS-5833 */	
           JOIN ORDERDETAIL OD (NOLOCK) ON P.OrderKey = OD.OrderKey
           WHERE PD.storerkey = @c_StorerKey   /* WMS-5833 */	
             AND PD.dropid = @c_DropID                /* WMS-5833 */	
             AND OD.UserDefine05 > '0') as PriceLabel,
          PACKDETAIL.DropID, ISNULL(CODELKUP.Short, 'N') AS ShowCartonID, /* WMS-5833 */
          ORDERS.Loadkey,
          ORDERS.Externorderkey
    FROM PACKHEADER (NOLOCK) 
    JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN ORDERS (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)
    JOIN (SELECT LabelNo, SUM(Qty) as TotQty
          FROM PACKDETAIL (NOLOCK)
          WHERE PACKDETAIL.storerkey = @c_StorerKey 
          AND PACKDETAIL.dropid = @c_DropID
          GROUP BY LabelNo) as LabelQty
          ON PACKDETAIL.LabelNo = LabelQty.LabelNo
    LEFT OUTER JOIN CODELKUP CODELKUP (NOLOCK) ON ( CODELKUP.LISTNAME = 'REPORTCFG' AND CODELKUP.Code = 'ShowCartonID' 
                                                    AND CODELKUP.Long = 'r_dw_carton_manifest_label_28_rdt' AND CODELKUP.Storerkey = ORDERS.StorerKey ) /* WMS-5833 */		
    WHERE PACKDETAIL.storerkey = @c_StorerKey /* WMS-5833 */	
    AND PACKDETAIL.dropid = @c_DropID	/* WMS-5833 */													  
    GROUP BY PACKHEADER.PickSlipNo, 
             PACKHEADER.Orderkey,
             PACKHEADER.OrderRefNo,
             PACKDETAIL.LabelNo,
             PACKDETAIL.CartonNo,
             PACKDETAIL.Sku,
             LabelQty.TotQty, 
             ORDERS.UserDefine04,
             PACKDETAIL.DropID, ISNULL(CODELKUP.Short, 'N'),  /* WMS-5833 */
             ORDERS.Loadkey,
             ORDERS.Externorderkey
       
                 
END  

GO