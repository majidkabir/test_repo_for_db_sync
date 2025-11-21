SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_LP_LOADSHEET_005                              */      
/* Creation Date: 20-SEP-2022                                              */    
/* Copyright: LF Logistics                                                 */    
/* Written by: CHONGCS                                                     */    
/*                                                                         */    
/* Purpose:WMS-20783 ID-ADIDAS-Loading Sheet Report                        */     
/*                                                                         */      
/* Called By: RPT_LP_LOADSHEET_005                                         */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */  
/* 20-Sep-2022  CHONGCS  1.0  DevOps Combine Script                        */   
/***************************************************************************/          
CREATE PROC [dbo].[isp_RPT_LP_LOADSHEET_005] (  
      @c_Loadkey  NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE  @c_Storerkey   NVARCHAR(15)                           
         ,  @c_Type        NVARCHAR(1) = '1'                      
         ,  @c_DataWindow  NVARCHAR(60) = 'RPT_LP_LOADSHEET_005'  
         ,  @c_RetVal      NVARCHAR(255)    

       SELECT
            mb.MbolKey
            ,oh.LoadKey
            ,mb.Vessel
            ,mb.Equipment
            ,ISNULL(mb.DRIVERName,'') AS DRIVERName
            ,mb.Carrieragent
            ,oh.ExternOrderKey
            ,oh.C_Company as Shipto
            ,sum(pd.Qty)QtyPcs
            ,QtyCTN = PAD.labelctn
            FROM Orders oh WITH (nolock)
            JOIN mbol MB WITH (nolock) on oh.Mbolkey=mb.Mbolkey
            JOIN pickdetail pd WITH  (nolock)on oh.Orderkey=pd.Orderkey
            CROSS APPLY (select count(distinct LabelNo) AS labelctn
                         from PackHeader ph (nolock) join PackDetail pk (nolock) on ph.PickSlipNo=pk.PickSlipNo
                         WHERE ph.OrderKey=oh.OrderKey and ph.StorerKey=oh.StorerKey) AS PAD 
            where oh.Loadkey=@c_Loadkey
            group by
            mb.MbolKey
            ,oh.LoadKey
            ,mb.Vessel
            ,mb.Equipment
            ,mb.DRIVERName
            ,mb.Carrieragent
            ,oh.ExternOrderKey
            ,oh.C_Company
            ,oh.Orderkey
            ,oh.StorerKey
            ,pad.labelctn
            order by Shipto,ExternOrderKey

END  

GO