SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: RPT_LP_STKOUTRPT_002                               */        
/* Creation Date: 29-JUL-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: CHONGCS                                                  */    
/*                                                                      */    
/* Purpose: WMS-23141 [MY] - WMS - UA - CR Add Carton Quantity          */
/*                    in Stock Out Report                               */      
/*                                                                      */        
/* Called By: RPT_LP_STKOUTRPT_002                                      */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 29-Jul-2023  CHONGCS   1.0  DevOps Combine Script                    */     
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_LP_STKOUTRPT_002] (
      @c_loadkey NVARCHAR(10)        
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        
        
     DECLARE @n_StartTCnt       INT  
         , @n_Continue        INT = 1  
         , @n_Err             INT = 0  
         , @c_ErrMsg          NVARCHAR(255) = ''  
         , @b_success         INT = 1  
  
   SELECT ORDERDETAIL.Sku,     
          ORDERS.StorerKey,     
          ORDERS.ExternOrderKey,     
          ORDERDETAIL.OrderLineNumber,     
          ORDERDETAIL.OpenQty,     
          ORDERDETAIL.QtyAllocated,     
          ORDERDETAIL.QtyPicked,     
          CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN ORDERS.DeliveryDate ELSE ORDERS.OrderDate END AS OrderDate,         
          (ORDERDETAIL.OpenQty - (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked)) shortages,     
          CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN ORDERS.Consigneekey ELSE ORDERS.OrderKey END AS OrderKey,         
          ORDERS.B_Company,  
          ORDERDETAIL.Lottable02,    
          ORDERDETAIL.Lottable04,      
          SKU.Descr,                  
          ORDERDETAIL.UOM,            
          LOADPLAN.LoadKey,       
          ORDERS.Notes,               
          ISNULL(CL1.Short,'N') AS ShowConsigneekey,
          P.CaseCnt  
   FROM ORDERS WITH (NOLOCK)  
   JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )     
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON ( LOADPLANDETAIL.OrderKey = ORDERS.OrderKey )  
   JOIN LOADPLAN WITH (NOLOCK) ON ( LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)  
   JOIN SKU WITH (NOLOCK) ON ( ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.StorerKey = SKU.StorerKey)   
   JOIN PACK P WITH (NOLOCK) ON P.PackKey = SKU.packkey   
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON ( CL1.Listname = 'REPORTCFG' AND CL1.Code = 'ShowConsigneeKey' AND   
                                             CL1.Storerkey = ORDERS.Storerkey AND  
                                             CL1.Long = 'RPT_LP_STKOUTRPT_002' )  
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON ( CL2.Listname = 'REPORTCFG' AND CL2.Code = 'ShowDeliveryDate' AND   
                                             CL2.Storerkey = ORDERS.Storerkey AND  
                                             CL2.Long = 'RPT_LP_STKOUTRPT_002' )  
     
   WHERE ( 0 < (ORDERDETAIL.OpenQty - (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked))) AND  
         ( LOADPLAN.LoadKey = @c_Loadkey )  
  
  
QUIT_SP:  
END -- procedure    

GO