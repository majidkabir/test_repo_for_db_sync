SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/    
/* Stored Proc: [API].[isp_ECOMP_GetOrderStatus]                        */    
/* Creation Date: 14-JUN-2019                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: Performance Tune                                            */    
/*        :                                                             */    
/* Called By: ECOM PackHeader - ue_saveend                              */    
/*          :                                                           */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 05-Aug-2021 NJOW01   1.0   WMS-17104 add config to skip get tracking */    
/*                            no from userdefine04                      */  
/* 08-JUL-2023 Alex01   1.1   Clone from WMS EXCEED script              */    
/* 29-DEC-2023 Alex02   1.2   Filter with PackTask table                */
/* 09-FEB-2024 Alex03   1.3   PAC-326 sort by packed sku                */
/* 17-MAY-2024 Alex04   1.4   PAC-342 bug fixed                         */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetOrderStatus] (
     @c_Orderkey             NVARCHAR(10)  
   , @c_OrderStatusJson      NVARCHAR(MAX)      = ''  OUTPUT
   , @c_PickSlipNo           NVARCHAR(10)       = ''
)
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_StartTCnt          INT               = @@TRANCOUNT    
         , @n_Continue           INT               = 1    
   
   DECLARE @c_ExternOrderkey     NVARCHAR(50)      = ''
         , @c_LoadKey            NVARCHAR(10)      = ''
         , @c_ConsigneeKey       NVARCHAR(15)      = ''
         , @c_ShipperKey         NVARCHAR(15)      = ''
         , @c_SalesMan           NVARCHAR(30)      = ''
         , @c_Route              NVARCHAR(10)      = ''
         , @c_UserDefine03       NVARCHAR(20)      = ''
         , @c_UserDefine04       NVARCHAR(40)      = ''
         , @c_UserDefine05       NVARCHAR(20)      = ''
         , @c_Status             NVARCHAR(10)      = ''
         , @c_SOStatus           NVARCHAR(10)      = ''
         , @c_TrackingNo         NVARCHAR(40)      = ''
         , @c_StorerKey          NVARCHAR(15)      = ''

   SET @c_OrderStatusJson          = ''
   SET @c_Orderkey               = ISNULL(RTRIM(@c_Orderkey), '')

   DECLARE @t_PackDetail AS TABLE (
      StorerKey   NVARCHAR(15)   NULL,
      SKU         NVARCHAR(40)   NULL,
      QTY         INT            
   )

   IF @c_Orderkey <> ''
   BEGIN
      IF @c_PickSlipNo <> ''
      BEGIN
         INSERT INTO @t_PackDetail (StorerKey, SKU, QTY)
         SELECT StorerKey, SKU, QTY
         FROM PACKDETAIL (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo
      END
      
      SET @c_OrderStatusJson = (
                                 SELECT PTD.Orderkey           As 'OrderKey'
                                       ,PTD.Storerkey          As 'StorerKey'
                                       ,PTD.Sku                As 'SKU'
                                       ,PTD.QtyAllocated       As 'QtyAllocated' 
                                       ,ISNULL(SUM(PD.Qty),0)  As 'QtyPacked'
                                       ,CASE WHEN  PTD.QtyAllocated = ISNULL(SUM(PD.Qty),0) THEN 1 ELSE 0 END As 'Packed'
                                       ,S.Descr As 'Description' 
                                 FROM PACKTASKDETAIL  PTD WITH (NOLOCK)   
                                 --Alex04 (Begin)  *PackTaskDetail.PickSlipNo could be blank
                                 --LEFT JOIN PACKDETAIL PD  WITH (NOLOCK) ON  
                                 --                                           (PTD.PickSlipNo = PD.PickSlipNo)  
                                 --                                       AND (PTD.Storerkey = PD.Storerkey)  
                                 --                                       AND (PTD.Sku = PD.Sku) 
                                 LEFT JOIN @t_PackDetail PD ON (PTD.Storerkey = PD.Storerkey)  
                                                            AND (PTD.Sku = PD.Sku) 
                                 --Alex04 (End)
                                 JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PTD.Storerkey AND S.SKU = PTD.SKU 
                                 WHERE PTD.Orderkey = @c_Orderkey    
                                 --Alex02 Begin
                                 AND EXISTS ( SELECT 1 FROM [dbo].[PackTask] PT WITH (NOLOCK) 
                                    WHERE PT.TaskBatchNo = PTD.TaskBatchNo AND PT.OrderKey = PTD.OrderKey )
                                 --Alex02 End
                                 GROUP  BY PTD.Orderkey  
                                       ,PTD.Storerkey  
                                       ,PTD.Sku  
                                       ,PTD.QtyAllocated  
                                       ,S.Descr
                                 ORDER BY CASE WHEN PTD.QtyAllocated = ISNULL(SUM(PD.Qty),0) THEN 1 ELSE 0 END --Alex03
                                 FOR JSON PATH
                               )
   END

   SET @c_OrderStatusJson = CASE WHEN ISNULL(RTRIM(@c_OrderStatusJson), '') = '' THEN '[]' ELSE @c_OrderStatusJson END
QUIT_SP:     
END -- procedure 
GO