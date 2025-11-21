SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/                
/* Store Procedure: isp_CartonManifestLabel28                                 */                
/* Creation Date: 04-Dec-2019                                                 */                
/* Copyright: LFL                                                             */                
/* Written by: WLChooi                                                        */                
/*                                                                            */                
/* Purpose: WMS-11264 - Convert to call SP, For printing from PB              */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_dw_carton_manifest_label_28                                  */                
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
    
CREATE PROC [dbo].[isp_CartonManifestLabel28]               
       (@c_Pickslipno       NVARCHAR(10),
        @c_CartonNoStart    NVARCHAR(5),
        @c_CartonNoEnd      NVARCHAR(5) ) 
                       
AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_WARNINGS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue        INT = 1


   SELECT PACKHEADER.PickSlipNo,
          PACKHEADER.OrderRefNo,
          PACKDETAIL.LabelNo,
          PACKDETAIL.CartonNo,
          PACKDETAIL.Sku, 
          (SELECT ISNULL(MAX(P2.CartonNo), 0) 
           FROM PACKDETAIL P2 (NOLOCK) 
           WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo
           --AND P2.storerkey = @c_StorerKey           /* WMS-5833 */	
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
           WHERE --PD.storerkey = @c_StorerKey   /* WMS-5833 */	
             --AND PD.dropid = @c_DropID                /* WMS-5833 */	
             --AND 
             PD.PickSlipNo = @c_Pickslipno
             AND PD.CartonNo BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)
             AND OD.UserDefine05 > '0') as PriceLabel,
          PACKDETAIL.DropID, ISNULL(CODELKUP.Short, 'N') AS ShowCartonID, /* WMS-5833 */
          ORDERS.Loadkey,
          ORDERS.Externorderkey
    FROM PACKHEADER (NOLOCK) 
    JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN ORDERS (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)
    JOIN (SELECT LabelNo, SUM(Qty) as TotQty
          FROM PACKDETAIL (NOLOCK)
          WHERE --PACKDETAIL.storerkey = @c_StorerKey 
          --AND PACKDETAIL.dropid = @c_DropID
          --AND 
          PACKDETAIL.PickSlipNo = @c_Pickslipno
          AND PACKDETAIL.CartonNo BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)
          GROUP BY LabelNo) as LabelQty
          ON PACKDETAIL.LabelNo = LabelQty.LabelNo
    LEFT OUTER JOIN CODELKUP CODELKUP (NOLOCK) ON ( CODELKUP.LISTNAME = 'REPORTCFG' AND CODELKUP.Code = 'ShowCartonID' 
                                                    AND CODELKUP.Long = 'r_dw_carton_manifest_label_28_rdt' AND CODELKUP.Storerkey = ORDERS.StorerKey ) /* WMS-5833 */		
    WHERE --PACKDETAIL.storerkey = @c_StorerKey /* WMS-5833 */	
    --AND PACKDETAIL.dropid = @c_DropID	/* WMS-5833 */	
    --AND 
    PACKDETAIL.PickSlipNo = @c_Pickslipno
    AND PACKDETAIL.CartonNo BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)												  
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