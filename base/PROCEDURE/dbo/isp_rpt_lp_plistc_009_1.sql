SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_LP_PLISTC_009_1                            */        
/* Creation Date: 06-DEC-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-21180 (TW)                                              */      
/*                                                                      */        
/* Called By: RPT_LP_PLISTC_009_1         								*/        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 06-DEC-2022  WZPang   1.0  DevOps Combine Script                     */     
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_LP_PLISTC_009_1] (
      @c_LoadKey        NVARCHAR(10)  
    , @c_PreGenRptData  NVARCHAR(10)     
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

   DECLARE @d_ExprDate DateTime  
   SELECT @d_ExprDate = NULL  
  
   SELECT DISTINCT ORDERS.ExternOrderKey,     
                   ORDERS.C_Company,     
                   ORDERS.Status,     
                   ORDERS.LabelPrice    
   FROM LOADPLANDETAIL (NOLOCK)  
   JOIN ORDERDETAIL (NOLOCK) ON LoadPlanDetail.LoadKey = ORDERDETAIL.LoadKey  
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey  
   WHERE LoadPlanDetail.LoadKey = @c_LoadKey


END -- procedure    

GO